# Decentralized Skill Certification Platform

A blockchain-based peer-to-peer skill validation system that enables transparent professional certification through consensus-driven evaluations. The platform leverages distributed assessment to create immutable, verifiable credentials while maintaining evaluator accountability through reputation mechanisms.

## Overview

This smart contract provides a decentralized alternative to traditional skill certification, where multiple evaluators assess candidates and reach consensus on their competency. The system maintains transparency, prevents bias, and rewards evaluators who provide consistent assessments aligned with group consensus.

## Key Features

- **Peer-to-peer skill validation**: Multiple evaluators assess each candidate
- **Consensus-driven certification**: Requires minimum evaluators and passing score threshold
- **Reputation system**: Evaluators earn or lose reputation based on assessment quality
- **Skill-specific expertise tracking**: Domain reputation separate from overall reputation
- **Immutable certification records**: Blockchain-based credential storage
- **Anti-gaming mechanisms**: Evaluator limits and self-assessment prevention

## Platform Constants

- **Minimum Evaluators Required**: 3 evaluators per assessment
- **Passing Score Threshold**: 70 out of 100
- **Maximum Evaluators**: 20 per assessment
- **Consensus Variance Tolerance**: 15 points deviation
- **Reputation Penalty**: 5 points for outlier assessments
- **Reputation Reward**: 2 points for consensus-aligned assessments

## Core Functionality

### User Registration

Users must register before participating as candidates or evaluators.

```clarity
(register-user)
```

### Skill Management

Platform administrator can create new skill categories with custom requirements.

```clarity
(create-skill skill-name skill-description min-score skill-domain)
```

Parameters:
- `skill-name`: Name of the skill (max 50 characters)
- `skill-description`: Detailed description (max 200 characters)
- `min-score`: Minimum passing score (1-100)
- `skill-domain`: Category domain (max 50 characters)

### Assessment Workflow

#### 1. Start Assessment

Candidates initiate certification assessment for a specific skill.

```clarity
(start-assessment skill-id)
```

#### 2. Submit Evaluation

Registered evaluators submit scores for candidate assessments.

```clarity
(submit-evaluation skill-id candidate-principal score)
```

Requirements:
- Evaluator must be registered
- Cannot evaluate yourself
- Score must be 0-100
- Cannot submit duplicate evaluation
- Maximum 20 evaluators per assessment

#### 3. Finalize Assessment

Candidate finalizes assessment once minimum evaluators have submitted scores.

```clarity
(finalize-assessment skill-id)
```

This function:
- Validates minimum evaluator requirement (3)
- Calculates final certification status
- Updates evaluator reputations based on consensus
- Records certification if passing threshold met

## Data Structures

### User Profiles

Tracks comprehensive user information including:
- Registration status
- Certified skill IDs (up to 20)
- Overall reputation score
- Total evaluations performed
- Consensus deviation count

### Skill-Specific Evaluator Stats

Maintains domain expertise metrics:
- Domain reputation score
- Number of evaluations in domain
- Consensus-aligned evaluation count

### Skill Categories

Defines certification requirements:
- Skill name and description
- Minimum passing score
- Domain classification

### Active Assessments

Stores ongoing assessment data:
- List of evaluators and scores
- Certification status
- Creation block height
- Average score
- Standard deviation

## Read-Only Functions

### User Information

```clarity
(get-user-profile user-principal)
(get-user-reputation user-principal)
(get-skill-domain-reputation user-principal skill-id)
```

### Skill Information

```clarity
(get-skill-info skill-id)
```

### Assessment Information

```clarity
(get-assessment-details skill-id candidate-principal)
(get-evaluator-count skill-id candidate-principal)
(get-assessment-analytics skill-id candidate-principal)
```

## Reputation System

### How Reputation Works

Evaluators earn reputation by providing assessments that align with group consensus:

- **Reward**: Evaluators within consensus tolerance receive +2 reputation
- **Penalty**: Evaluators outside consensus tolerance receive -5 reputation
- **Consensus Tolerance**: 15 points deviation from average score

### Dual Reputation Tracking

1. **Overall Reputation**: Cumulative across all skill domains
2. **Domain Reputation**: Skill-specific expertise tracking

This dual system allows evaluators to build specialized expertise and helps candidates identify qualified assessors.

## Error Codes

- `ERR-UNAUTHORIZED-ACCESS (u100)`: Insufficient permissions
- `ERR-USER-ALREADY-REGISTERED (u101)`: User already exists
- `ERR-USER-NOT-FOUND (u102)`: User profile not found
- `ERR-INSUFFICIENT-EVALUATOR-COUNT (u103)`: Need more evaluators
- `ERR-ASSESSMENT-ALREADY-ACTIVE (u104)`: Assessment exists
- `ERR-EVALUATOR-CAPACITY-EXCEEDED (u105)`: Too many evaluators
- `ERR-INVALID-SCORE-VALUE (u106)`: Score outside 0-100 range
- `ERR-SKILL-DOES-NOT-EXIST (u107)`: Skill not found
- `ERR-INVALID-INPUT-PARAMETERS (u108)`: Invalid input data

## Security Considerations

- Only contract owner can create skills
- Self-evaluation is prevented
- Evaluator count limits prevent spam
- Reputation cannot go below zero
- Input validation on all parameters
- Assessment immutability after finalization

## Use Cases

- Professional skill certification
- Educational credential verification
- Technical competency assessment
- Peer review systems
- Freelancer qualification platforms
- Industry-specific licensing

## Technical Implementation

### Statistical Analysis

The contract implements statistical measures for consensus analysis:
- **Average Score**: Arithmetic mean of all evaluations
- **Standard Deviation**: Measure of score distribution consistency
- **Consensus Detection**: Identifies outlier evaluations

### List Management

Utilizes Clarity's bounded list types with maximum capacity of 20 items for:
- Evaluator tracking
- Score aggregation
- Certified skill accumulation

## Administrative Functions

Only the contract owner (deployer) can:
- Create new skill categories
- Define skill requirements
- Set domain classifications

All other functions are permissionless for registered users.

## Getting Started

1. Deploy contract to Stacks blockchain
2. Administrator creates initial skill categories
3. Users register on platform
4. Candidates start assessments
5. Evaluators submit scores
6. Candidates finalize certifications