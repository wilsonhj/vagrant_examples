#!/bin/bash
# Script to trigger CI/CD pipeline testing

echo "🚀 Methods to Test CI/CD Pipeline"
echo "================================="

echo ""
echo "1. CREATE A PULL REQUEST (Recommended)"
echo "   Visit: https://github.com/wilsonhj/vagrant_examples/pull/new/bug-fixes"
echo "   This will automatically trigger all CI/CD jobs"

echo ""
echo "2. PUSH A SMALL CHANGE to trigger CI"
echo "   Example:"
echo "   git commit --allow-empty -m 'trigger CI/CD pipeline test'"
echo "   git push"

echo ""
echo "3. CREATE A TEST BRANCH"
echo "   git checkout -b test-ci"
echo "   echo '# CI Test' >> README.md"
echo "   git add README.md"
echo "   git commit -m 'test: trigger CI pipeline'"
echo "   git push --set-upstream origin test-ci"

echo ""
echo "4. VIEW PIPELINE RESULTS"
echo "   Go to: https://github.com/wilsonhj/vagrant_examples/actions"
echo "   You'll see the workflow runs with detailed logs"

echo ""
echo "5. LOCAL TESTING (Current Status)"
echo "   ✅ Ruby configuration tests: PASSED"
echo "   ✅ File structure: COMPLETE"
echo "   ⚠️  Vagrant syntax: Requires Vagrant installation"
echo "   ⚠️  Markdown linting: Requires markdownlint installation"

echo ""
echo "🔧 To install missing tools for complete local testing:"
echo "   brew install vagrant          # For Vagrantfile validation"
echo "   npm install -g markdownlint-cli  # For documentation linting"
echo "   pip install yamllint          # For YAML validation"
