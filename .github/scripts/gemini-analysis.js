#!/usr/bin/env node

/**
 * 🤖 Gemini AI Code Analysis Script
 *
 * This script analyzes smart contract changes using Google Gemini AI
 * to provide insights on security, gas optimization, and best practices.
 */

const fs = require('fs');
const path = require('path');
const { GoogleGenerativeAI } = require('@google/generative-ai');

// Parse command line arguments
const args = process.argv.slice(2);
const apiFlag = args.indexOf('--api-key');
const filesFlag = args.indexOf('--files');
const outputFlag = args.indexOf('--output');

const apiKey = apiFlag !== -1 ? args[apiFlag + 1] : process.env.GEMINI_API_KEY;
const filesList = filesFlag !== -1 ? args[filesFlag + 1] : '';
const outputFile = outputFlag !== -1 ? args[outputFlag + 1] : 'gemini-analysis.json';

if (!apiKey) {
  console.error('❌ Error: Gemini API key is required');
  console.log('Usage: node gemini-analysis.js --api-key YOUR_KEY --files "file1.sol,file2.js" --output analysis.json');
  process.exit(1);
}

/**
 * 🤖 Initialize Gemini AI
 */
const genAI = new GoogleGenerativeAI(apiKey);
const model = genAI.getGenerativeModel({
  model: 'gemini-1.5-flash',
  generationConfig: {
    temperature: 0.3,
    topP: 0.8,
    topK: 40,
    maxOutputTokens: 8192,
  }
});

/**
 * 📋 Smart Contract Analysis Prompt Template
 */
const ANALYSIS_PROMPT = `
You are an expert smart contract security auditor and blockchain developer specializing in DeFi, EVM rollups, and cross-chain protocols.

Analyze the following smart contract changes and provide comprehensive feedback on:

## 🔍 Security Analysis
- Identify potential vulnerabilities (reentrancy, overflow/underflow, access control issues)
- Check for proper input validation and edge cases
- Assess gas optimization opportunities
- Verify adherence to Solidity best practices

## 💡 Code Quality & Best Practices
- Code organization and structure
- Naming conventions and documentation
- Error handling patterns
- Upgradeability and proxy patterns

## ⚡ Gas Optimization
- Identify expensive operations
- Suggest optimization opportunities
- Batch operations potential
- Storage optimization opportunities

## 🌉 Cross-Chain & Bridge Specific
- Bridge security considerations
- Oracle integration patterns
- Data availability verification
- Cross-chain validation logic

## 📊 Tokenomics & Economic Model
- Token minting/burning logic
- Fee mechanisms
- Governance token implications
- Economic incentive alignment

## 🎯 AndeChain Specific Considerations
- Compatibility with Celestia DA
- Integration with BSC bridges
- Latin American financial use cases
- Regulatory compliance considerations

Please provide:
1. **Risk Level**: LOW/MEDIUM/HIGH/CRITICAL
2. **Security Score**: 0-100
3. **Gas Efficiency Score**: 0-100
4. **Code Quality Score**: 0-100
5. **Specific Recommendations**: Actionable suggestions
6. **Lines of Code**: Specific line references when possible

Focus on practical, actionable feedback that helps improve the security and efficiency of our AndeChain protocol.
`;

/**
 * 📁 Read file content
 */
function readFile(filePath) {
  try {
    const fullPath = path.resolve(filePath);
    if (fs.existsSync(fullPath)) {
      return fs.readFileSync(fullPath, 'utf8');
    }
    return `// File not found: ${filePath}`;
  } catch (error) {
    return `// Error reading file ${filePath}: ${error.message}`;
  }
}

/**
 * 🤖 Analyze code with Gemini
 */
async function analyzeWithGemini(codeContent, fileName) {
  try {
    console.log(`🤖 Analyzing ${fileName} with Gemini AI...`);

    const prompt = `${ANALYSIS_PROMPT}\n\n## 📄 File: ${fileName}\n\n\`\`\`solidity\n${codeContent}\n\`\`\``;

    const result = await model.generateContent(prompt);
    const response = await result.response;
    const text = response.text();

    console.log(`✅ Analysis completed for ${fileName}`);
    return {
      file: fileName,
      analysis: text,
      timestamp: new Date().toISOString()
    };
  } catch (error) {
    console.error(`❌ Error analyzing ${fileName}:`, error.message);
    return {
      file: fileName,
      error: error.message,
      timestamp: new Date().toISOString()
    };
  }
}

/**
 * 📊 Extract scores from analysis
 */
function extractScores(analysis) {
  const scores = {
    security: null,
    gasEfficiency: null,
    codeQuality: null,
    riskLevel: 'UNKNOWN'
  };

  // Extract Security Score
  const securityMatch = analysis.match(/Security Score[:\s]*(\d+)/i);
  if (securityMatch) scores.security = parseInt(securityMatch[1]);

  // Extract Gas Efficiency Score
  const gasMatch = analysis.match(/Gas Efficiency Score[:\s]*(\d+)/i);
  if (gasMatch) scores.gasEfficiency = parseInt(gasMatch[1]);

  // Extract Code Quality Score
  const qualityMatch = analysis.match(/Code Quality Score[:\s]*(\d+)/i);
  if (qualityMatch) scores.codeQuality = parseInt(qualityMatch[1]);

  // Extract Risk Level
  const riskMatch = analysis.match(/Risk Level[:\s]*(LOW|MEDIUM|HIGH|CRITICAL)/i);
  if (riskMatch) scores.riskLevel = riskMatch[1].toUpperCase();

  return scores;
}

/**
 * 📋 Generate summary
 */
function generateSummary(analyses) {
  const summary = {
    totalFiles: analyses.length,
    successfulAnalyses: analyses.filter(a => !a.error).length,
    failedAnalyses: analyses.filter(a => a.error).length,
    averageScores: {
      security: 0,
      gasEfficiency: 0,
      codeQuality: 0
    },
    riskDistribution: {
      LOW: 0,
      MEDIUM: 0,
      HIGH: 0,
      CRITICAL: 0,
      UNKNOWN: 0
    },
    recommendations: [],
    timestamp: new Date().toISOString()
  };

  let totalSecurity = 0;
  let totalGas = 0;
  let totalQuality = 0;
  let scoreCount = 0;

  analyses.forEach(analysis => {
    if (!analysis.error) {
      const scores = extractScores(analysis.analysis);

      if (scores.security !== null) {
        totalSecurity += scores.security;
        scoreCount++;
      }
      if (scores.gasEfficiency !== null) totalGas += scores.gasEfficiency;
      if (scores.codeQuality !== null) totalQuality += scores.codeQuality;

      summary.riskDistribution[scores.riskLevel] = (summary.riskDistribution[scores.riskLevel] || 0) + 1;

      // Extract recommendations
      const recommendations = analysis.analysis.match(/- (?:✅|⚠️|❌) [^\n]+/g) || [];
      summary.recommendations.push(...recommendations.slice(0, 5)); // Limit to top recommendations
    }
  });

  if (scoreCount > 0) {
    summary.averageScores.security = Math.round(totalSecurity / scoreCount);
    summary.averageScores.gasEfficiency = Math.round(totalGas / scoreCount);
    summary.averageScores.codeQuality = Math.round(totalQuality / scoreCount);
  }

  return summary;
}

/**
 * 🎯 Main execution function
 */
async function main() {
  console.log('🚀 Starting Gemini AI Code Analysis...');
  console.log(`📋 Files to analyze: ${filesList}`);

  const files = filesList.split(',').map(f => f.trim()).filter(f => f);
  const analyses = [];

  for (const file of files) {
    const content = readFile(file);
    const analysis = await analyzeWithGemini(content, file);
    analyses.push(analysis);

    // Add delay to respect rate limits
    await new Promise(resolve => setTimeout(resolve, 1000));
  }

  const summary = generateSummary(analyses);

  const result = {
    summary,
    analyses,
    metadata: {
      version: '1.0.0',
      model: 'gemini-1.5-flash',
      timestamp: new Date().toISOString()
    }
  };

  // Save results
  fs.writeFileSync(outputFile, JSON.stringify(result, null, 2));
  console.log(`✅ Analysis complete! Results saved to: ${outputFile}`);
  console.log(`📊 Analyzed ${result.summary.totalFiles} files`);
  console.log(`🔒 Average Security Score: ${result.summary.averageScores.security}/100`);
  console.log(`⚡ Average Gas Efficiency: ${result.summary.averageScores.gasEfficiency}/100`);
  console.log(`📝 Average Code Quality: ${result.summary.averageScores.codeQuality}/100`);

  // Print summary to console
  console.log('\n📋 Quick Summary:');
  console.log('='.repeat(50));
  if (result.summary.recommendations.length > 0) {
    console.log('🎯 Top Recommendations:');
    result.summary.recommendations.slice(0, 5).forEach((rec, i) => {
      console.log(`  ${i + 1}. ${rec}`);
    });
  }
  console.log('='.repeat(50));
}

// Execute main function
if (require.main === module) {
  main().catch(error => {
    console.error('❌ Fatal error:', error);
    process.exit(1);
  });
}

module.exports = {
  analyzeWithGemini,
  generateSummary,
  extractScores
};