# Chat Template Guide for MLX Models

## Overview

Each language model is trained with specific conversation formatting, called "chat templates". Using the wrong format can cause models to:
- Generate self-conversations (multiple turns instead of one response)
- Misunderstand instructions
- Produce lower quality outputs

## Problem: OpenELM Self-Conversations

When using OpenELM models with standard instruction formats, they tend to generate entire conversations instead of single responses. This happens because the model wasn't trained with those specific markers.

## Solution: Model-Specific Chat Templates

### 1. OpenELM Models
**Format**: Simple, no role markers
```
{system_prompt}

{user_message}
```
**Note**: No "User:", "Assistant:", or other markers that might trigger self-conversation.

### 2. Qwen Models (ChatML Format)
**Format**: ChatML with special tokens
```
<|im_start|>system
{system_prompt}<|im_end|>
<|im_start|>user
{user_message}<|im_end|>
<|im_start|>assistant
```
**Important**: Requires `eos_token: "<|im_end|>"` in tokenizer config

### 3. SmolLM Models
**Format**: ChatML (same as Qwen)
```
<|im_start|>system
{system_prompt}<|im_end|>
<|im_start|>user
{user_message}<|im_end|>
<|im_start|>assistant
```

### 4. Gemma Models
**Format**: Google's specific format
```
<start_of_turn>user
{user_message}<end_of_turn>
<start_of_turn>model
```

### 5. Llama 3.x Models
**Format**: Llama 3 specific
```
<|begin_of_text|><|start_header_id|>system<|end_header_id|>

{system_prompt}<|eot_id|><|start_header_id|>user<|end_header_id|>

{user_message}<|eot_id|><|start_header_id|>assistant<|end_header_id|>
```

### 6. Phi Models
**Format**: Microsoft Phi format
```
{system_prompt}

Instruct: {user_message}
Output: 
```

### 7. TinyLlama Models
**Format**: Simple instruction format
```
{system_prompt}

### Human: {user_message}
### Assistant:
```

## Implementation in Code

### Current Approach (Hardcoded)
The app currently detects model types and applies hardcoded templates. This works but isn't ideal because:
- Templates might change with model versions
- New models require code updates
- Some models have multiple valid templates

### Better Approach (Dynamic Loading)
1. Check `tokenizer_config.json` for `chat_template` field
2. Use model-specific template if found
3. Fall back to known templates based on model family
4. Use simple format as last resort

### Example tokenizer_config.json
```json
{
  "chat_template": "{% for message in messages %}<|im_start|>{{ message.role }}\n{{ message.content }}<|im_end|>\n{% endfor %}<|im_start|>assistant\n",
  "eos_token": "<|im_end|>",
  "pad_token": "<|endoftext|>"
}
```

## Debugging Chat Template Issues

### Symptoms of Wrong Template:
1. **Self-conversations**: Model generates "User:" and "Assistant:" turns
2. **Repetition**: Model repeats the instruction format
3. **Confusion**: Model doesn't understand the task
4. **Format bleeding**: Response includes template markers

### How to Debug:
1. Print the formatted prompt before sending to model
2. Check if response contains role markers
3. Try simpler formats if complex ones fail
4. Look for chat_template in model's tokenizer_config.json

## MLX Swift Considerations

MLX Swift's `LLMModelFactory` handles tokenization internally through the `processor.prepare()` method. However:
- It expects raw prompts, not pre-formatted conversations
- The framework should apply templates automatically if included in model files
- When templates are missing, it falls back to simple text format

## Recommendations

1. **For OpenELM**: Use minimal formatting, just the message
2. **For Qwen/SmolLM**: Use proper ChatML format with tokens
3. **For instruction models**: Check specific format requirements
4. **When unsure**: Start with simple format and adjust based on output

## Future Improvements

1. Load chat templates dynamically from tokenizer_config.json
2. Implement proper Jinja2 template rendering
3. Add template validation before inference
4. Provide UI feedback about template usage
5. Allow users to customize templates per model

## References

- [Hugging Face Chat Templates](https://huggingface.co/docs/transformers/main/en/chat_templating)
- [MLX-LM Documentation](https://github.com/ml-explore/mlx-lm)
- [Model-specific documentation on HuggingFace]