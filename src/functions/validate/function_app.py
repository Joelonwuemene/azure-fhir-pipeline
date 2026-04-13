import azure.functions as func
import logging
import json
import os
import requests
from azure.identity import ManagedIdentityCredential

app = func.FunctionApp(http_auth_level=func.AuthLevel.FUNCTION)

FHIR_URL = os.environ.get("FHIR_URL", "")
FHIR_SCOPE = f"{FHIR_URL}/.default"


@app.route(route="validate", methods=["POST"])
def validate_fhir_resource(req: func.HttpRequest) -> func.HttpResponse:
    """
    FHIR validation gate. Accepts a FHIR resource JSON body, calls the AHDS
    $validate operation, and returns an OperationOutcome. Rejects resources
    with error or fatal severity before they reach the FHIR store.
    """
    logging.info("FHIR $validate function triggered")

    # Parse and validate request body
    try:
        resource = req.get_json()
    except ValueError:
        return func.HttpResponse(
            json.dumps({"error": "Invalid JSON body. A FHIR resource is required."}),
            status_code=400,
            mimetype="application/json"
        )

    resource_type = resource.get("resourceType")
    if not resource_type:
        return func.HttpResponse(
            json.dumps({"error": "Missing resourceType. Body must be a valid FHIR resource."}),
            status_code=400,
            mimetype="application/json"
        )

    if not FHIR_URL:
        logging.error("FHIR_URL environment variable is not set")
        return func.HttpResponse(
            json.dumps({"error": "FHIR service URL not configured"}),
            status_code=500,
            mimetype="application/json"
        )

    # Acquire managed identity token for FHIR service
    try:
        credential = ManagedIdentityCredential()
        token = credential.get_token(FHIR_SCOPE)
    except Exception as e:
        logging.error(f"Token acquisition failed: {e}")
        return func.HttpResponse(
            json.dumps({"error": "Authentication failed. Check Managed Identity configuration."}),
            status_code=500,
            mimetype="application/json"
        )

    headers = {
        "Authorization": f"Bearer {token.token}",
        "Content-Type": "application/fhir+json",
        "Accept": "application/fhir+json"
    }

    validate_url = f"{FHIR_URL}/{resource_type}/$validate"
    logging.info(f"Calling $validate: {validate_url}")

    # Call FHIR $validate
    try:
        response = requests.post(
            validate_url,
            json=resource,
            headers=headers,
            timeout=30
        )
    except requests.exceptions.Timeout:
        logging.error(f"$validate request timed out after 30s: {validate_url}")
        return func.HttpResponse(
            json.dumps({"error": "FHIR $validate request timed out"}),
            status_code=504,
            mimetype="application/json"
        )
    except requests.exceptions.RequestException as e:
        logging.error(f"$validate request failed: {e}")
        return func.HttpResponse(
            json.dumps({"error": f"FHIR $validate request failed: {str(e)}"}),
            status_code=502,
            mimetype="application/json"
        )

    # Parse OperationOutcome and evaluate severity
    try:
        outcome = response.json()
    except ValueError:
        logging.error(f"Non-JSON response from $validate: {response.text[:200]}")
        return func.HttpResponse(
            json.dumps({"error": "Unexpected non-JSON response from FHIR $validate"}),
            status_code=502,
            mimetype="application/json"
        )

    # Check for error or fatal issues in OperationOutcome
    issues = outcome.get("issue", [])
    blocking_issues = [
        i for i in issues
        if i.get("severity") in ("error", "fatal")
    ]

    if blocking_issues:
        logging.warning(
            f"$validate rejected {resource_type}: "
            f"{len(blocking_issues)} blocking issue(s)"
        )
        return func.HttpResponse(
            json.dumps(outcome),
            status_code=422,
            mimetype="application/fhir+json"
        )

    logging.info(f"$validate passed for {resource_type}: all OK")
    return func.HttpResponse(
        json.dumps(outcome),
        status_code=response.status_code,
        mimetype="application/fhir+json"
    )
