# Scope-Based Indentation Standard

This document defines the indentation standard for the Essence project, which enforces **scope-based indentation** for method chaining to improve code readability and maintain consistency.

## The Problem: Double-Indentation Anti-Pattern

Many Ruby codebases suffer from the "double-indentation anti-pattern" where method calls in a chain are indented relative to the first method call, creating excessive and visually distracting indentation:

```ruby
# ❌ WRONG: Double-indentation anti-pattern
cleaned_words = name.to_s
    .gsub(/[^a-zA-Z0-9_\s]/, "")  # Extra indentation creates visual noise
    .split(/[\s_]+/)              # Hard to scan and read
    .reject(&:empty?)             # Not based on logical scope
    .map(&:capitalize)            # Inconsistent with surrounding code
```

This pattern has several problems:
- **Visual noise**: Creates unnecessary horizontal space that makes code harder to scan
- **Inconsistent scoping**: The indentation doesn't reflect the actual scope structure
- **Poor readability**: Makes it difficult to quickly understand the code's logical flow
- **Maintenance burden**: Changes to variable names require re-indenting the entire chain

## The Solution: Scope-Based Indentation

Our standard enforces **scope-based indentation** where method calls are indented based on their logical scope level, not their relationship to the receiver:

```ruby
# ✅ CORRECT: Scope-based indentation
cleaned_words = name.to_s
.gsub(/[^a-zA-Z0-9_\s]/, "")   # Aligned with the scope level
.split(/[\s_]+/)               # Same indentation as line above  
.reject(&:empty?)              # Consistent and readable
.map(&:capitalize)             # Easy to scan and understand
```

## Core Principles

### 1. Scope-Level Alignment
Method calls in a chain should be indented at the **same level as the scope they belong to**, not relative to the receiver or first method call.

### 2. Two-Space Indentation
Each scope level adds exactly **2 spaces** of indentation. This applies to:
- Method definitions inside classes/modules
- Code inside conditionals (`if`, `unless`, `case`)
- Code inside blocks (`each`, `map`, etc.)
- Code inside method calls with blocks

### 3. Consistent Chain Indentation
All method calls in a chain should have the **same indentation level**, determined by their scope.

## Examples

### Basic Method Chaining

```ruby
# ✅ CORRECT
result = data
.filter { |item| item.valid? }
.map { |item| item.transform }
.compact

# ❌ WRONG
result = data
    .filter { |item| item.valid? }   # Extra indentation
    .map { |item| item.transform }
    .compact
```

### Inside Conditionals

```ruby
# ✅ CORRECT: Chain aligned with conditional scope (4 spaces)
if complex_condition?
  result = user_data
  .select { |user| user.active? }
  .map(&:email)
  .uniq
end

# ❌ WRONG: Double indentation inside conditional
if complex_condition?
  result = user_data
      .select { |user| user.active? }  # Wrong: 6 spaces
      .map(&:email)
      .uniq
end
```

### Inside Blocks

```ruby
# ✅ CORRECT: Chain aligned with block scope (6 spaces)
users.each do |user|
  formatted_name = user.name
  .strip
  .downcase
  .gsub(/\s+/, "_")
  
  puts formatted_name
end

# ❌ WRONG: Double indentation inside block
users.each do |user|
  formatted_name = user.name
      .strip           # Wrong: 10 spaces
      .downcase
      .gsub(/\s+/, "_")
end
```

### Complex Nested Scopes

```ruby
# ✅ CORRECT: Each scope level adds exactly 2 spaces
class DataProcessor
  def process_users
    # Level 1: Class method scope (2 spaces)
    all_data = fetch_data
    .validate
    .normalize
    
    if all_data.any?
      # Level 2: Conditional scope (4 spaces)
      filtered_data = all_data
      .select { |item| item.active? }
      .reject { |item| item.expired? }
      
      filtered_data.each do |item|
        # Level 3: Block scope (6 spaces)
        processed_item = item
        .transform
        .sanitize
        .save
        
        log_result(processed_item)
      end
    end
  end
end
```

## RuboCop Configuration

Our `.rubocop.yml` configuration enforces this standard:

```yaml
# Disable standard method call indentation to prevent double-indentation
Layout/MultilineMethodCallIndentation:
  Enabled: false

# Enforce 2-space indentation consistently  
Layout/IndentationWidth:
  Width: 2

# Ensure consistent indentation for multiline operations
Layout/MultilineOperationIndentation:
  EnforcedStyle: indented
```

### Why We Disable `MultilineMethodCallIndentation`

The standard RuboCop `Layout/MultilineMethodCallIndentation` cop supports these styles:
- `aligned`: Aligns with the first method call (creates our anti-pattern)
- `indented`: Adds extra indentation relative to receiver (also problematic)
- `indented_relative_to_receiver`: Indents relative to receiver (complex and inconsistent)

None of these styles support true scope-based indentation, so we disable this cop and rely on our documented standard instead.

## Migration Strategy

When updating existing code:

1. **Identify chains with double-indentation**: Look for method calls indented more than their logical scope
2. **Realign with scope**: Move method calls to align with their scope level
3. **Verify consistency**: Ensure all calls in a chain have the same indentation
4. **Test thoroughly**: Run tests to ensure no functional changes

Example migration:

```ruby
# Before (double-indentation)
cleaned_words = name.to_s
    .gsub(/[^a-zA-Z0-9_\s]/, "")
    .split(/[\s_]+/)
    .reject(&:empty?)
    .map(&:capitalize)

# After (scope-based)
cleaned_words = name.to_s
.gsub(/[^a-zA-Z0-9_\s]/, "")
.split(/[\s_]+/)
.reject(&:empty?)
.map(&:capitalize)
```

## Benefits

1. **Improved Readability**: Code flows more naturally and is easier to scan
2. **Consistent Structure**: Indentation reflects logical scope, not arbitrary alignment
3. **Maintainability**: Changes to variable names don't require re-indenting chains
4. **Team Consistency**: Clear, documented standard prevents inconsistent formatting
5. **Tool Compatibility**: Works well with standard Ruby tooling and editors

## Enforcement

- **RuboCop**: Configured to enforce 2-space indentation and prevent problematic patterns
- **Code Reviews**: Team members should verify scope-based indentation in pull requests  
- **Documentation**: This standard should be referenced in onboarding and style guides
- **Examples**: Reference files show correct patterns (see `examples/indentation_examples.rb`)

## Questions and Edge Cases

### Q: What about very long variable names?
**A:** Scope-based indentation is independent of variable name length. Always align with the scope level.

### Q: What about single-line chains?
**A:** Single-line chains are fine and don't require special indentation:
```ruby
result = data.filter(&:valid?).map(&:process).compact
```

### Q: What about assignment with complex right-hand sides?
**A:** The method chain indentation should still be scope-based:
```ruby
# ✅ CORRECT
complex_variable_name_here = some_complex_method_call(arg1, arg2)
.chain_method
.another_method
```

### Q: What about return statements?
**A:** Same rules apply:
```ruby
# ✅ CORRECT  
return user_data
.select { |user| user.active? }
.map(&:email)
.uniq
```

---

This standard helps maintain clean, readable, and maintainable Ruby code across the entire project.