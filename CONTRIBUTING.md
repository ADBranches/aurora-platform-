# Contributing to Aurora

## Code Style
- **Python**: Adhere to PEP 8. Use `flake8` with `--max-line-length=120`. Install `pre-commit` for automatic checks.
- **Node.js**: Follow Airbnb's ESLint rules. Run `npm run lint` before committing.
- **APIs**: Design RESTful endpoints with FastAPI (Python) or Express (Node.js). Use OpenAPI for documentation.
- **File Structure**: Place services in `services/<service-name>`, scripts in `scripts/`, and configurations in `config/`.

## Commit Messages
- Use semantic commits: `feat: <description>`, `fix: <description>`, `docs: <description>`, `chore: <description>`.
- Example: `feat: add stock-out prediction endpoint to api-gateway`.

## Branching
- Use `feature/<feature-name>` for new features (e.g., `feature/predictive-alerts`).
- Use `fix/<issue-number>` for bug fixes (e.g., `fix/123`).
- Pull requests must target `develop` and require at least one reviewer.

## Testing
- Write unit tests with `pytest` (Python) or `jest` (Node.js). Aim for >80% coverage.
- Integration tests should simulate API calls and database interactions.
- Run tests locally: `docker-compose run --rm app pytest` or `npm test`.

## Pre-Commit Hooks
- Install: `pip install pre-commit && pre-commit install`.
- Config (` .pre-commit-config.yaml`):
  ```yaml
  repos:
    - repo: https://github.com/pre-commit/pre-commit-hooks
      rev: v4.4.0
      hooks:
        - id: trailing-whitespace
        - id: end-of-file-fixer
    - repo: https://github.com/PyCQA/flake8
      rev: 6.0.0
      hooks:
        - id: flake8
          args: [--max-line-length=120]