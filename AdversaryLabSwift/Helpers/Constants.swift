//
//  Constants.swift
//  AdversaryLabSwift
//
//  Created by Adelita Schule on 1/23/18.
//  Copyright © 2018 Operator Foundation. All rights reserved.
//

import Foundation
import CreateML

let packetStatsKey = "Packet:Stats"

// MARK: Allowed Connections
let allowedConnectionsKey = "Allowed:Connections"
let allowedIncomingKey = "Allowed:Incoming:Packets"
let allowedOutgoingKey = "Allowed:Outgoing:Packets"

let allowedIncomingDatesKey = "Allowed:Incoming:Dates"
let allowedOutgoingDatesKey = "Allowed:Outgoing:Dates"
let allowedConnectionsTimeDiffKey = "Allowed:Connections:TimeDifference"

let allowedIncomingOffsetSequencesKey = "Allowed:Incoming:OffsetSequence"
let allowedOutgoingOffsetSequencesKey = "Allowed:Outgoing:OffsetSequence"
let allowedIncomingFloatingSequencesKey = "Allowed:Incoming:FloatingSequence"
let allowedOutgoingFloatingSequencesKey = "Allowed:Outgoing:FloatingSequence"

let allowedPacketsSeenKey = "Allowed:Connections:Seen"
let allowedPacketsAnalyzedKey = "Allowed:Connections:Analyzed"

// MARK: Blocked Connections
let blockedConnectionsKey = "Blocked:Connections"
let blockedIncomingKey = "Blocked:Incoming:Packets"
let blockedOutgoingKey = "Blocked:Outgoing:Packets"

let blockedIncomingDatesKey = "Blocked:Incoming:Dates"
let blockedOutgoingDatesKey = "Blocked:Outgoing:Dates"
let blockedConnectionsTimeDiffKey = "Blocked:Connections:TimeDifference"

let blockedIncomingOffsetSequencesKey = "Blocked:Incoming:OffsetSequence"
let blockedOutgoingOffsetSequencesKey = "Blocked:Outgoing:OffsetSequence"
let blockedIncomingFloatingSequencesKey = "Blocked:Incoming:FloatingSequence"
let blockedOutgoingFloatingSequencesKey = "Blocked:Outgoing:FloatingSequence"

let blockedPacketsSeenKey = "Blocked:Connections:Seen"
let blockedPacketsAnalyzedKey = "Blocked:Connections:Analyzed"

// MARK: - Scores

// MARK: Tests
let testResultsKey = "TestResults"
let tlsTestResultsKey = "TestResults:TLS"
let allFeaturesTLSTestResultsKey = "TestResults:AllFeatures:TLS"

// Entropy
let allowedOutgoingEntropyKey = "Allowed:Outgoing:Entropy"
let allowedIncomingEntropyKey = "Allow:Incoming:Entropy"
let allowedOutgoingEntropyAccuracyKey = "Allowed:Outgoing:Entropy:Accuracy"
let allowedIncomingEntropyAccuracyKey = "Allow:Incoming:Entropy:Accuracy"

let blockedIncomingEntropyKey = "Blocked:Incoming:Entropy"
let blockedOutgoingEntropyKey = "Blocked:Outgoing:Entropy"
let blockedOutgoingEntropyAccuracyKey = "Blocked:Outgoing:Entropy:Accuracy"
let blockedIncomingEntropyAccuracyKey = "Blocked:Incoming:Entropy:Accuracy"

// Length
let allowedIncomingLengthKey = "Allowed:Incoming:Length"
let allowedIncomingLengthAccuracyKey = "Allowed:Incoming:Length:Accuracy"
let allowedOutgoingLengthKey = "Allowed:Outgoing:Length"
let allowedOutgoingLengthAccuracyKey = "Allowed:Outgoing:Length:Accuracy"

let blockedIncomingLengthKey = "Blocked:Incoming:Length"
let blockedIncomingLengthAccuracyKey = "Blocked:Incoming:Length:Accuracy"
let blockedOutgoingLengthKey = "Blocked:Outgoing:Length"
let blockedOutgoingLengthAccuracyKey = "Blocked:Outgoing:Length:Accuracy"

// Sequences
let allowedIncomingFloatAccuracyKey = "Allowed:Incoming:FloatSequence:Accuracy"
let allowedOutgoingFloatAccuracyKey = "Allowed:Outgoing:FloatSequence:Accuracy"
let blockedIncomingFloatAccuracyKey = "Blocked:Incoming:FloatSequence:Accuracy"
let blockedOutgoingFloatAccuracyKey = "Blocked:Outgoing:FloatSequence:Accuracy"

let allowedIncomingOffsetAccuracyKey = "Allowed:Incoming:OffsetSequence:Accuracy"
let allowedOutgoingOffsetAccuracyKey = "Allowed:Outgoing:OffsetSequence:Accuracy"
let blockedIncomingOffsetAccuracyKey = "Blocked:Incoming:OffsetSequence:Accuracy"
let blockedOutgoingOffsetAccuracyKey = "Blocked:Outgoing:OffsetSequence:Accuracy"

// All Features
let allowedAllFeaturesAccuracyKey = "Allowed:AllFeatures:Accuracy"
let allowedAllFeaturesIncomingLengthKey = "Allowed:AllFeatures:Incoming:Length"
let allowedAllFeaturesOutgoingLengthKey = " Allowed:AllFeatures:Outgoing:Length"
let allowedAllFeaturesIncomingEntropyKey = "Allowed:AllFeatures:Incoming:Entropy"
let allowedAllFeaturesOutgoingEntropyKey = "Allowed:AllFeatures:Outgoing:Entropy"
let allowedAllFeaturesTimingKey = "Allowed:AllFeatures:Timing"
let allowedAllFeaturesTLSKey = "Allowed:AllFeatures:TLS"
let blockedAllFeaturesAccuracyKey = "Blocked:AllFeatures:Accuracy"
let blockedAllFeaturesIncomingLengthKey = "Blocked:AllFeatures:Incoming:Length"
let blockedAllFeaturesOutgoingLengthKey = "Blocked:AllFeatures:Outgoing:Length"
let blockedAllFeaturesIncomingEntropyKey = "Blocked:AllFeatures:Incoming:Entropy"
let blockedAllFeaturesOutgoingEntropyKey = "Blocked:AllFeatures:Outgoing:Entropy"
let blockedAllFeaturesTimingKey = "Blocked:AllFeatures:Timing"
let blockedAllFeaturesTLSKey = "Blocked:AllFeatures:TLS"

// Timing
let allowedTimingKey = "Allowed:Timing"
let allowedTimingAccuracyKey = "Allowed:Timing:Accuracy"
let blockedTimingKey = "Blocked:Timing"
let blockedTimingAccuracyKey = "Blocked:Timing:Accuracy"

// TLS A seperate results dictionary is needed for the values but not the accuracies because values are Strings not Doubles
//let tlsTestResultValuesKey = "TestResults:TLS:Values"
let allowedTLSKey = "Allowed:TLS12"
let blockedTLSKey = "Blocked:TLS12"

let allowedTLSAccuracyKey = "Allowed:TLS12:Accuracy"
let blockedTLSAccuracyKey = "Blocked:TLS12:Accuracy"

// MARK: Training
// MARK: Lengths
let packetLengthsTrainingResultsKey = "PacketLengths:Training:Results"
let incomingRequiredLengthKey = "Incoming:Required:Length"
let incomingForbiddenLengthKey = "Incoming:Forbidden:Length"
let incomingLengthsTAccKey = "Incoming:Lengths:TrainingAccuracy"
let incomingLengthsVAccKey = "Incoming:Lengths:Validation:Accuracy"
let incomingLengthsEAccKey = "Incoming:Lengths:Evaluation:Accuracy"

let outgoingRequiredLengthKey = "Outgoing:Required:Length"
let outgoingForbiddenLengthKey = "Outgoing:Forbidden:Length"
let outgoingLengthsTAccKey = "Outgoing:Lengths:TrainingAccuracy"
let outgoingLengthsVAccKey = "Outgoing:Lengths:ValidationAccuracy"
let outgoingLengthsEAccKey = "Outgoing:Lengths:EvaluationAccuracy"

// MARK: Float Sequences
let floatSequencesTrainingResultsKey = "FloatSequences:Training:Results"

let incomingFloatTrainingSequencesKey = "Incoming:FloatSequence:TrainingSequences"
let outgoingFloatTrainingSequencesKey = "Outgoing:FloatSequence:TrainingSequences"

let incomingFloatSequencesTAccKey = "Incoming:FloatSequences:TrainingAccuracy"
let incomingFloatSequencesVAccKey = "Incoming:FloatSequences:ValidationAccuracy"
let incomingFloatSequencesEAccKey = "Incoming:FloatSequences:EvaluationAccuracy"

let outgoingFloatSequencesTAccKey = "Outgoing:FloatSequences:TrainingAccuracy"
let outgoingFloatSequencesVAccKey = "Outgoing:FloatSequences:ValidationAccuracy"
let outgoingFloatSequencesEAccKey = "Outgoing:FloatSequences:EvaluationAccuracy"

let incomingRequiredFloatSequencesKey = "Incoming:Required:FloatSequence"
let incomingForbiddenFloatSequencesKey = "Incoming:Forbidden:FloatSequence"
let incomingFloatSequenceScoresKey = "Incoming:FloatSequence:Scores"
let outgoingRequiredFloatSequencesKey = "Outgoing:Required:FloatSequence"
let outgoingForbiddenFloatSequencesKey = "Outgoing:Forbidden:FloatSequence"
let outgoingFloatSequenceScoresKey = "Outgoing:FloatSequence:Scores"

// MARK: Offset Sequences
let offsetSequencesTrainingResultsKey = "OffsetSequences:Training:Results"

let incomingOffsetTrainingSequencesKey = "Incoming:Offset:TrainingSequences"
let incomingOffsetTrainingSequenceOffsetsKey = "Incoming:Offset:TrainingSequenceOffsets"
let outgoingOffsetTrainingSequencesKey = "Outgoing:Offset:TrainingSequences"
let outgoingOffsetTrainingSequenceOffsetsKey = "Outgoing:Offset:TrainingSequenceOffsets"

let incomingOffsetSequencesTAccKey = "Incoming:OffsetSequences:TrainingAccuracy"
let incomingOffsetSequencesVAccKey = "Incoming:OffsetSequences:ValidationAccuracy"
let incomingOffsetSequencesEAccKey = "Incoming:OffsetSequences:EvaluationAccuracy"

let outgoingOffsetSequencesTAccKey = "Outgoing:OffsetSequences:TrainingAccuracy"
let outgoingOffsetSequencesVAccKey = "Outgoing:OffsetSequences:ValidationAccuracy"
let outgoingOffsetSequencesEAccKey = "Outgoing:OffsetSequences:EvaluationAccuracy"

let requiredOffsetSequenceKey = "Incoming:Required:OffsetSequence"
let requiredOffsetByteCountKey = "Incoming:Required:OffsetByteCount"
let requiredOffsetIndexKey = "Incoming:Required:OffsetIndex"
let requiredOffsetAccuracyKey = "Incoming:Required:OffsetAccuracy"

let forbiddenOffsetSequenceKey = "Incoming:Forbidden:OffsetSequence"
let forbiddenOffsetByteCountKey = "Incoming:Forbidden:OffsetByteCount"
let forbiddenOffsetIndexKey = "Incoming:Forbidden:OffsetIndex"
let forbiddenOffsetAccuracyKey = "Incoming:Forbidden:OffsetAccuracy"

let incomingForbiddenOffsetKey = "Incoming:Forbidden:Offset"
let incomingRequiredOffsetKey = "Incoming:Required:Offset"
let outgoingRequiredOffsetKey = "Outgoing:Required:Offset"
let outgoingForbiddenOffsetKey = "Outgoing:Forbidden:Offset"

// MARK: Entropy
let entropyTrainingResultsKey = "Entropy:Training:Results"
let incomingRequiredEntropyKey = "Incoming:Allowed:Entropy"
let incomingForbiddenEntropyKey = "Incoming:Blocked:Entropy"
let incomingEntropyTAccKey = "IncomingEntropyTrainingAccuracy"
let incomingEntropyVAccKey = "IncomingEntropyValidationAccuracy"
let incomingEntropyEAccKey = "IncomingEntropyEvaluationAccuracy"

let outgoingRequiredEntropyKey = "OutgoingRequiredEntropy"
let outgoingForbiddenEntropyKey = "OutgoingForbiddenEntropy"
let outgoingEntropyTAccKey = "OutgoingEntropyTrainingAccuracy"
let outgoingEntropyVAccKey = "OutgoingEntropyValidationAccuracy"
let outgoingEntropyEAccKey = "OutgoingEntropyEvaluationAccuracy"

// MARK: Timing
let timeDifferenceTrainingResultsKey = "TimeDifference:Training:Results"
let timeDifferenceTestResultsKey = "TimeDifference:Test:Results"
let requiredTimeDiffKey = "RequiredTimeDifference"
let forbiddenTimeDiffKey = "ForbiddenTimeDifference"
let timeDiffTAccKey = "TimeDifferenceTAccuracy"
let timeDiffVAccKey = "TimeDifferenceVAccuracy"
let timeDiffEAccKey = "TimeDifferenceEAccuracy"

// MARK: TLS
let allowedTlsCommonNameKey = "Allowed:Outgoing:TLS:CommonName"
let blockedTlsCommonNameKey = "Blocked:Outgoing:TLS:CommonName"

let tlsTrainingResultsKey = "TLS:Training:Results"
let requiredTLSKey = "RequiredTLS"
let forbiddenTLSKey = "ForbiddenTLS"
let tlsTrainingAccuracyKey = "TLS:Training:Accuracy"
let tlsTestAccuracyKey = "TLS:Test:Accuracy"
let tlsTAccKey = "TLSTrainingAccuracy"
let tlsVAccKey = "TLSValidationAccuracy"
let tlsEAccKey = "TLSEvaluationAccuracy"

// MARK: All Features
let allFeaturesTrainingAccuracyKey = "AllFeatures:Training:Accuracy"
let allFeaturesTAccKey = "AllFeatures:TrainingAccuracy"
let allFeaturesVAccKey = "AllFeatures:ValidationAccuracy"
let allFeaturesEAccKey = "AllFeatures:EvaluationAccuracy"
let allFeaturesTimeTrainingResultsKey = "AllFeatures:TimeDifference:Training:Results"
let allFeaturesEntropyTrainingResultsKey = "AllFeatures:Entropy:Training:Results"
let allFeaturesLengthTrainingResultsKey = "AllFeatures:PacketLengths:Training:Results"
let allFeaturesTLSTraininResultsKey = "AllFeatures:TLS:Training:Results"

// MARK: - PubSub
let newConnectionMessage = "NewConnectionAdded"
let newConnectionsChannel = "New:Connections:Channel"

// MARK: -  Human Readable Strings
let analyzingAllowedConnectionsString = "Analyzing allowed connection"
let analyzingBlockedConnectionString = "Analyzing blocked connection"
let scoringPacketLengthsString = "Scoring packet lengths"
let scoringPacketTimingString = "Scoring packet timing"
let scoringEntropyString = "Scoring entropy"
let scoringTLSNamesString = "Scoring TLS names"
let scoringOffsetsString = "Scoring offset sequences"
let scoringFloatSequencesString = "Scoring float sequences"

// MARK: - Queues
let analysisQueue = DispatchQueue(label: "AnalysisQueue")
let testQueue = DispatchQueue(label: "AdversaryTestQueue")

// MARK: - Models
// MARK: Model Filenames
let modelFileExtension = "mlmodel"

let allClassifierName = "AllFeatures_Classifier"
//let allTimingRegressorName = "AllFeatures_TimeDifference_Regressor"
//let allInEntropyRegressorName = "AllFeatures_Entropy_In_Regressor"
//let allOutEntropyRegressorName = "AllFeatures_Entropy_Out_Regressor"
//let allInPacketLengthRegressorName = "AllFeatures_PacketLength_In_Regressor"
//let allOutPacketLengthRegressorName = "AllFeatures_PacketLength_Out_Regressor"
//let allTLSRegressorName = "AllFeatures_TLS_Regressor"

let timingRegressorName = "TimeDifference_Regressor"
let timingClassifierName = "TimeDifference_Classifier"

let inEntropyRegressorName = "Entropy_In_Regressor"
let outEntropyRegressorName = "Entropy_Out_Regressor"
let inEntropyClassifierName = "Entropy_In_Classifier"
let outEntropyClassifierName = "Entropy_Out_Classifier"

let inLengthRegressorName = "Length_In_Regressor"
let outLengthRegressorName = "Length_Out_Regressor"
let inLengthClassifierName = "Length_In_Classifier"
let outLengthClassifierName = "Length_Out_Classifier"

let inFloatClassifierName = "Float_In_Classifier"
let outFloatClassifierName = "Float_Out_Classifier"
let inOffsetClassifierName = "Offset_In_Classifier"
let outOffsetClassifierName = "Offset_Out_Classifier"

let tlsRegressorName = "TLS_Regressor"
let tlsClassifierName = "TLS_Classifier"

// MARK: Model Metadata
let entropyRegressorMetadata = MLModelMetadata(author: "Operator Foundation", shortDescription: "Predicts Required/Forbidden entropy for a connection", version: "1.0")
let entropyClassifierMetadata = MLModelMetadata(author: "Operator Foundation", shortDescription: "Predicts whether a given entropy is from an allowed or blocked connection.", version: "1.0")
let timingRegressorMetadata = MLModelMetadata(author: "Operator Foundation", shortDescription: "Predicts required/forbidden entropy for a connection", version: "1.0")
let timingClassifierMetadata = MLModelMetadata(author: "Operator Foundation", shortDescription: "Predicts whether a timing is from an allowed or blocked connection.", version: "1.0")
let lengthsRegressorMetadata = MLModelMetadata(author: "Operator Foundation", shortDescription: "Predicts required/forbidden length for a connection", version: "1.0")
let lengthsClassifierMetadata = MLModelMetadata(author: "Operator Foundation", shortDescription: "Predicts whether a packet length is from an allowed or blocked connection.", version: "1.0")
let tlsRegressorMetadata = MLModelMetadata(author: "Operator Foundation", shortDescription: "Predicts required/forbidden TLS name for a connection", version: "1.0")
let tlsClassifierMetadata = MLModelMetadata(author: "Operator Foundation", shortDescription: "Predicts whether a TLS name is from an allowed or blocked connection.", version: "1.0")

let allFeaturesClassifierMetadata = MLModelMetadata(author: "Operator Foundation", shortDescription: "Predicts whether a given set of features is from an allowed or blocked connection.", version: "1.0")
let allFeaturesEntropyRegressorMetadata = MLModelMetadata(author: "Operator Foundation", shortDescription: "Predicts Required/Forbidden entropy for a connection given all features", version: "1.0")
let allFeaturesTimingRegressorMetadata = MLModelMetadata(author: "Operator Foundation", shortDescription: "Predicts required/forbidden entropy for a connection given all features", version: "1.0")
let allFeaturesLengthsRegressorMetadata = MLModelMetadata(author: "Operator Foundation", shortDescription: "Predicts required/forbidden lengths for a connection given all features", version: "1.0")
let allFeaturesTLSRegressorMetadata = MLModelMetadata(author: "Operator Foundation", shortDescription: "Predicts required/forbidden TLS name for a connection", version: "1.0")

let floatClassifierMetadata = MLModelMetadata(author: "Operator Foundation", shortDescription: "Predicts whether a given float sequence is from an allowed or blocked connection.", version: "1.0")
let offsetClassifierMetadata = MLModelMetadata(author: "Operator Foundation", shortDescription: "Predicts whether a given offset sequence is from an allowed or blocked connection.", version: "1.0")


// MARK: - Helper Tool
let helperToolName = "org.operatorFoundation.AdversaryLabService"

// MARK: - Notifications
extension Notification.Name
{
    static let updateDBFilename = Notification.Name("UpdateDatabaseFilename")
    static let updateStats = Notification.Name("UpdatedConnectionStats")
    static let updateProgressIndicator = Notification.Name("UpdatedProgress")
}

// MARK: - Enums
enum KnownProtocolType {
    case TLS12 // TLS 1.2
}

enum PacketLengthError: Error
{
    case noOutPacketForConnection(String)
    case noInPacketForConnection(String)
    case unableToIncremementScore(packetSize: Int, connectionID: String)
}

enum PacketTimingError: Error
{
    case noOutPacketDateForConnection(String)
    case noInPacketDateForConnection(String)
    case unableToAddTimeDifference(timeDifference: TimeInterval, connectionID: String)
}

enum ClassificationLabel: String
{
    case allowed = "allowed"
    case blocked = "blocked"
}

enum ColumnLabel: String
{
    case length = "length"
    case outLength = "outgoingLength"
    case inLength = "incomingLength"
    case entropy = "entropy"
    case outEntropy = "outgoingEntropy"
    case inEntropy = "incomingEntropy"
    case timeDifference = "timeDifference"
    case tlsNames = "tlsNames"
    case classification = "classification"
    case direction = "direction"
}

enum PredictionKey: String
{
    case classificationProbability
    case classification
}

enum ServerCheckResult
{
    case okay(String?)
    case corruptRedisOnPort(pid: String)
    case otherProcessOnPort(name: String)
    case failure(String?)
}
