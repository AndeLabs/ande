# Contributing to AndeChain

Thank you for your interest in contributing to AndeChain! This document provides guidelines and standards for contributors.

## 🚀 Getting Started

### Prerequisites
- Git
- Docker & Docker Compose
- Node.js 18+
- Foundry (for smart contracts)
- Make

### Development Setup
```bash
# Clone the repository
git clone <repository-url>
cd andechain

# Install dependencies
make setup

# Start development environment
make start
```

## 📋 Development Standards

### Code Style
- **Solidity**: Follow [Solidity Style Guide](https://docs.soliditylang.org/en/latest/style-guide.html)
- **TypeScript**: Use ESLint + Prettier configuration
- **Shell Scripts**: Follow Google Shell Style Guide
- **Docker**: Use Dockerfile best practices

### Commit Messages
Follow [Conventional Commits](https://www.conventionalcommits.org/):
```
feat(scope): add new feature
fix(scope): correct bug
docs(scope): update documentation
refactor(scope): improve code structure
test(scope): add tests
chore(scope): maintenance tasks
```

### Branch Strategy
- `main` - Production branch
- `develop` - Integration branch
- `feature/*` - New features
- `bugfix/*` - Bug fixes
- `hotfix/*` - Urgent production fixes

## 🧪 Testing

### Smart Contracts
```bash
# Run all tests
make test

# Run with coverage
make coverage

# Run specific test
forge test --match-test testFunctionName
```

### Integration Tests
```bash
# Run integration tests
make test-integration

# Run with verbose output
make test-integration-verbose
```

## 📝 Documentation

### Required Documentation
- All public functions must have NatSpec comments
- Complex logic needs inline comments
- Architecture decisions documented in ADRs
- API documentation kept up-to-date

### Documentation Updates
- Update README.md for user-facing changes
- Update CHANGELOG.md for all changes
- Create ADRs for significant architectural decisions

## 🔍 Code Review Process

### PR Requirements
1. All tests pass
2. Code coverage >= 80%
3. Documentation updated
4. No linting errors
5. Security review for critical changes

### Review Checklist
- [ ] Code follows project standards
- [ ] Tests are comprehensive
- [ ] Documentation is accurate
- [ ] Security implications considered
- [ ] Performance impact assessed

## 🛡️ Security

### Security Guidelines
- Never commit private keys or secrets
- Use environment variables for configuration
- Follow smart contract security best practices
- Report security vulnerabilities privately

### Security Review
- All contract changes require security review
- Use tools like Slither for static analysis
- Consider gas optimization implications

## 🚀 Deployment

### Deployment Process
1. All tests pass in CI/CD
2. Code review approved
3. Security review completed
4. Documentation updated
5. Deployment to staging first
6. Production deployment with monitoring

### Version Management
- Use semantic versioning
- Tag releases with version numbers
- Maintain backward compatibility when possible

## 📞 Getting Help

- Create an issue for bugs or feature requests
- Join our Discord for discussions
- Check existing documentation first
- Follow the issue template when reporting bugs

## 📜 License

By contributing, you agree that your contributions will be licensed under the same license as the project.

---

Thank you for contributing to AndeChain! 🎉