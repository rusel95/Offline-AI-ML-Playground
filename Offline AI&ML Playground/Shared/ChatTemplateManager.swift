//
//  ChatTemplateManager.swift
//  Offline AI&ML Playground
//
//  Created by Assistant on 09.08.2025.
//

import Foundation

/// Manages chat templates for different models
/// Each model may have its own specific chat template format defined in tokenizer_config.json
@MainActor
class ChatTemplateManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = ChatTemplateManager()
    
    // MARK: - Chat Template Cache
    private var templateCache: [String: String] = [:]
    
    // MARK: - Known Chat Templates
    private let knownTemplates: [String: String] = [
        // Qwen models use ChatML format
        "qwen": """
            <|im_start|>system
            {{ system_message }}<|im_end|>
            {% for message in messages %}
            <|im_start|>{{ message.role }}
            {{ message.content }}<|im_end|>
            {% endfor %}
            <|im_start|>assistant
""",
        
        // Gemma models use specific format
        "gemma": """
            {% for message in messages %}
            <start_of_turn>{{ message.role == 'user' ? 'user' : 'model' }}
            {{ message.content }}<end_of_turn>
            {% endfor %}
            <start_of_turn>model
            """,
        
        // Llama models use specific format
        "llama": """
            <|begin_of_text|>{% if system_message %}<|start_header_id|>system<|end_header_id|>
            
            {{ system_message }}<|eot_id|>{% endif %}{% for message in messages %}<|start_header_id|>{{ message.role }}<|end_header_id|>
            
            {{ message.content }}<|eot_id|>{% endfor %}<|start_header_id|>assistant<|end_header_id|>
            """,
        
        // Phi models use their own format
        "phi": """
            {% if system_message %}{{ system_message }}
            
            {% endif %}{% for message in messages %}{% if message.role == 'user' %}Instruct: {{ message.content }}
            {% else %}Output: {{ message.content }}
            {% endif %}{% endfor %}Output: 
""",
        
        // SmolLM uses ChatML format
        "smollm": """
            <|im_start|>system
            {{ system_message }}<|im_end|>
            {% for message in messages %}
            <|im_start|>{{ message.role }}
            {{ message.content }}<|im_end|>
            {% endfor %}
            <|im_start|>assistant
""",
        
        // TinyLlama uses simple format
        "tinyllama": """
            {% if system_message %}{{ system_message }}
            
            {% endif %}{% for message in messages %}{% if message.role == 'user' %}### Human: {{ message.content }}
            {% else %}### Assistant: {{ message.content }}
            {% endif %}{% endfor %}### Assistant:
""",
        
        // OpenELM - use very simple format to avoid self-conversation
        "openelm": """
            {% if messages|length == 1 and system_message %}{{ system_message }}
            
            {% endif %}{{ messages[-1].content if messages else '' }}
""",
        
        // Default conversational format
        "default": """
            {% if system_message %}{{ system_message }}
            
            {% endif %}{% for message in messages %}{% if message.role == 'user' %}Human: {{ message.content }}
            {% else %}Assistant: {{ message.content }}
            {% endif %}
            {% endfor %}
            Assistant: 
"""
    ]
    
    private init() {
        print("💬 ChatTemplateManager initialized")
    }
    
    /// Load chat template from model's tokenizer_config.json
    func loadChatTemplate(for modelId: String) async -> String? {
        // Check cache first
        if let cached = templateCache[modelId] {
            return cached
        }
        
        // Try to load from tokenizer_config.json
        let modelPath = ModelFileManager.shared.getMLXModelDirectory(for: modelId)
        let tokenizerConfigPath = modelPath.appendingPathComponent("tokenizer_config.json")
        
        if FileManager.default.fileExists(atPath: tokenizerConfigPath.path) {
            do {
                let data = try Data(contentsOf: tokenizerConfigPath)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let chatTemplate = json["chat_template"] as? String {
                    print("✅ Found chat template in tokenizer_config.json for \(modelId)")
                    templateCache[modelId] = chatTemplate
                    return chatTemplate
                }
            } catch {
                print("⚠️ Failed to load tokenizer_config.json: \(error)")
            }
        }
        
        return nil
    }
    
    /// Get the appropriate chat template for a model
    func getChatTemplate(for model: AIModel) -> String {
        let modelName = model.name.lowercased()
        let modelId = model.id.lowercased()
        
        // Check for specific model types
        if modelName.contains("qwen") || modelId.contains("qwen") {
            return knownTemplates["qwen"]!
        } else if modelName.contains("gemma") || modelId.contains("gemma") {
            return knownTemplates["gemma"]!
        } else if modelName.contains("llama-3") || modelId.contains("llama-3") {
            return knownTemplates["llama"]!
        } else if modelName.contains("phi") || modelId.contains("phi") {
            return knownTemplates["phi"]!
        } else if modelName.contains("smollm") || modelId.contains("smollm") {
            return knownTemplates["smollm"]!
        } else if modelName.contains("tinyllama") || modelId.contains("tinyllama") {
            return knownTemplates["tinyllama"]!
        } else if modelName.contains("openelm") || modelId.contains("openelm") {
            return knownTemplates["openelm"]!
        }
        
        return knownTemplates["default"]!
    }
    
    /// Apply a chat template to messages (simplified version without Jinja2)
    func applyTemplate(_ template: String, messages: [ChatMessage], systemPrompt: String) -> String {
        var result = template
        
        // Replace system message
        result = result.replacingOccurrences(of: "{{ system_message }}", with: systemPrompt)
        result = result.replacingOccurrences(of: "{{system_message}}", with: systemPrompt)
        
        // Handle conditional system message
        if systemPrompt.isEmpty {
            // Remove system message blocks
            result = result.replacingOccurrences(of: """
                <|im_start|>system
                <|im_end|>
                """, with: "")
            result = result.replacingOccurrences(of: """
                <|start_header_id|>system<|end_header_id|>
                
                <|eot_id|>
                """, with: "")
            // Remove {% if system_message %} blocks
            result = removeConditionalBlocks(result, condition: "system_message", isEmpty: true)
        }
        
        // Build messages content
        var messagesContent = ""
        
        // Extract the message loop pattern
        if let loopMatch = extractLoop(from: result) {
            let (loopTemplate, loopContent) = loopMatch
            
            for (index, message) in messages.enumerated() {
                var messageBlock = loopContent
                
                // Replace role
                messageBlock = messageBlock.replacingOccurrences(of: "{{ message.role }}", with: message.role.rawValue)
                messageBlock = messageBlock.replacingOccurrences(of: "{{message.role}}", with: message.role.rawValue)
                
                // Replace content
                messageBlock = messageBlock.replacingOccurrences(of: "{{ message.content }}", with: message.content)
                messageBlock = messageBlock.replacingOccurrences(of: "{{message.content}}", with: message.content)
                
                // Handle role conditionals
                if message.role == .user {
                    messageBlock = messageBlock.replacingOccurrences(of: "{{ message.role == 'user' ? 'user' : 'model' }}", with: "user")
                    messageBlock = processIfStatements(messageBlock, role: "user")
                } else {
                    messageBlock = messageBlock.replacingOccurrences(of: "{{ message.role == 'user' ? 'user' : 'model' }}", with: "model")
                    messageBlock = processIfStatements(messageBlock, role: "assistant")
                }
                
                messagesContent += messageBlock
                
                // Add spacing if specified
                if index < messages.count - 1 && loopContent.contains("\n{% endfor %}") {
                    messagesContent += "\n"
                }
            }
            
            // Replace the loop with generated content
            result = result.replacingOccurrences(of: loopTemplate, with: messagesContent)
        }
        
        // Handle special case for last message reference
        if let lastMessage = messages.last {
            result = result.replacingOccurrences(of: "{{ messages[-1].content if messages else '' }}", with: lastMessage.content)
        }
        
        // Clean up any remaining template syntax
        result = cleanupTemplate(result)
        
        return result
    }
    
    // MARK: - Helper Methods
    
    private func extractLoop(from template: String) -> (String, String)? {
        // Look for {% for message in messages %} ... {% endfor %}
        let pattern = #"\{%\s*for\s+message\s+in\s+messages\s*%\}(.*?)\{%\s*endfor\s*%\}"#
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
           let match = regex.firstMatch(in: template, range: NSRange(template.startIndex..., in: template)) {
            
            let fullMatch = String(template[Range(match.range, in: template)!])
            let loopContent = String(template[Range(match.range(at: 1), in: template)!])
            
            return (fullMatch, loopContent)
        }
        
        return nil
    }
    
    private func processIfStatements(_ text: String, role: String) -> String {
        var result = text
        
        // Process {% if message.role == 'user' %} blocks
        let userPattern = #"\{%\s*if\s+message\.role\s*==\s*'user'\s*%\}(.*?)\{%\s*else\s*%\}(.*?)\{%\s*endif\s*%\}"#
        if let regex = try? NSRegularExpression(pattern: userPattern, options: [.dotMatchesLineSeparators]) {
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            
            for match in matches.reversed() {
                let userContent = String(result[Range(match.range(at: 1), in: result)!])
                let assistantContent = String(result[Range(match.range(at: 2), in: result)!])
                
                let replacement = role == "user" ? userContent : assistantContent
                result.replaceSubrange(Range(match.range, in: result)!, with: replacement)
            }
        }
        
        return result
    }
    
    private func removeConditionalBlocks(_ text: String, condition: String, isEmpty: Bool) -> String {
        var result = text
        
        // Pattern to match {% if condition %} ... {% endif %}
        let pattern = #"\{%\s*if\s+\#(condition)\s*%\}(.*?)\{%\s*endif\s*%\}"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
            if isEmpty {
                // Remove the entire block if condition is false
                result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
            }
        }
        
        return result
    }
    
    private func cleanupTemplate(_ text: String) -> String {
        var result = text
        
        // Remove any remaining template syntax
        result = result.replacingOccurrences(of: #"\{%.*?%\}"#, with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: #"\{\{.*?\}\}"#, with: "", options: .regularExpression)
        
        // Clean up extra whitespace
        result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return result
    }
}