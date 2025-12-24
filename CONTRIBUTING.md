# Contributing to Convex Salesforce Connector

Thank you for your interest in contributing! This document provides guidelines for contributing to the project.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/yourusername/convex-salesforce-connector.git`
3. Install dependencies: `npm install`
4. Create a branch: `git checkout -b feature/your-feature-name`

## Development Setup

### Prerequisites

- Node.js 18+
- [Convex account](https://convex.dev)
- [Salesforce Developer Edition](https://developer.salesforce.com/signup) or Scratch Org
- [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli)

### Local Development

1. Start Convex dev server:
   ```bash
   npm run dev
   ```

2. Connect to a Salesforce scratch org:
   ```bash
   sf org create scratch -f config/project-scratch-def.json -a my-scratch-org
   sf project deploy start -d salesforce/force-app -o my-scratch-org
   ```

## Code Style

- Use TypeScript for all Convex code
- Follow the existing code patterns
- Add comments for complex logic
- Keep functions focused and small

## Testing

### Convex Functions

Currently, we rely on integration testing. When adding new features:

1. Test locally with `npx convex dev`
2. Verify CDC events are processed correctly
3. Check sync status with `npm run status`

### Salesforce Apex

Run Apex tests:
```bash
npm run test:salesforce
```

Ensure all tests pass before submitting a PR.

## Pull Request Process

1. Update documentation if needed
2. Add tests for new functionality
3. Ensure all tests pass
4. Update CHANGELOG.md if applicable
5. Submit PR with clear description

## Adding New Objects

To add support for a new Salesforce object:

1. Add the object configuration to `convex/config.ts`
2. Generate a trigger: `npm run generate:trigger ObjectName`
3. Update the schema in `convex/schema.ts`
4. Test the sync

## Commit Messages

Use conventional commits:
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation
- `refactor:` Code refactoring
- `test:` Adding tests
- `chore:` Maintenance

## Questions?

Open an issue for:
- Bug reports
- Feature requests
- General questions

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
