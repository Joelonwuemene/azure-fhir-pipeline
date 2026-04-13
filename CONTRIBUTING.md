# Contributing

This repository is a reference implementation of a HIPAA-compliant HL7 v2.x to FHIR R4 transformation pipeline on Azure. Contributions that improve reproducibility, fix documentation gaps, or extend the architecture pattern are welcome.

## Before You Open a Pull Request

- Open an issue first describing the change and the problem it solves.
- All changes must maintain HIPAA-compliant design principles. No real PHI, subscription IDs, or credentials in any committed file.
- IaC changes must remain fully parameterized. No hardcoded resource names.
- Code changes to the validation Function must include a corresponding Postman test demonstrating the OperationOutcome response.

## Local Setup

See [docs/deployment-guide.md](docs/deployment-guide.md) for environment prerequisites and setup steps.

## Architecture Decisions

If your change involves a deliberate architecture tradeoff, add or update an ADR in `docs/decisions/`. See existing ADRs for the format.

## Code Style

- Python: PEP 8, type hints where practical
- Bicep: consistent use of parameters over hardcoded values, all resources tagged per the HIPAA tag schema
- Markdown: sentence case for headings, no trailing whitespace

## Contact

For questions about the architecture or integration patterns, reach out via [LinkedIn](https://linkedin.com/in/joel-onwuemene) or [joel.azurearchitect@proton.me](mailto:joel.azurearchitect@proton.me).
