# Scope-Based Indentation Standard

This document defines the indentation standard for the Essence project, which enforces **scope-based indentation** for method chaining to improve code readability and maintain consistency.

## When to Use Multi-Line Method Chaining

**IMPORTANT**: Keep method chains on a single line whenever possible. Only break them across multiple lines when:

1. The single line would exceed reasonable length (typically 120+ characters)
2. Inline comments are needed to explain each step
3. Complex arguments make the line hard to read

```ruby
# ✅ PREFERRED: Single line when reasonable
result = data.select(&:valid?).map(&:process).compact

# ✅ ACCEPTABLE: Multi-line only when necessary due to length/complexity
processed_user_data_with_validation = raw_user_input_from_csv_file
.strip
.split(/[,;|\t]/)  # Handle multiple delimiter types from different export formats
.reject { |field| field.empty? || field.match(/^\s*$/) }  # Remove empty and whitespace-only
.map { |field| sanitize_and_validate_user_field(field, strict_mode: true) }
.compact
```

## The Problem: Double-Indentation Anti-Pattern

When multi-line method chaining IS necessary, many Ruby codebases suffer from the "double-indentation anti-pattern":

```ruby
# ❌ WRONG: Double-indentation anti-pattern (only when multi-line is necessary)
processed_user_data_with_validation = raw_user_input_from_csv_file
    .strip                    # Extra indentation creates visual noise
    .split(/[,;|\t]/)         # Hard to scan and read
    .reject { |field| field.empty? || field.match(/^\s*$/) }
    .map { |field| sanitize_and_validate_user_field(field, strict_mode: true) }
    .compact                  # Inconsistent with surrounding code
```

## The Solution: Scope-Based Indentation (When Multi-Line is Needed)

When method chains must span multiple lines, use **scope-based indentation**:

```ruby
# ✅ CORRECT: Scope-based indentation (when multi-line is necessary)
processed_user_data_with_validation = raw_user_input_from_csv_file
.strip                    # Aligned with the scope level
.split(/[,;|\t]/)         # Same indentation as line above  
.reject { |field| field.empty? || field.match(/^\s*$/) }
.map { |field| sanitize_and_validate_user_field(field, strict_mode: true) }
.compact                  # Easy to scan and understand
```

## Core Principles

### 1. Prefer Single-Line Chains
Keep method chains on a single line unless they become too long or need inline documentation.

### 2. Scope-Level Alignment (Multi-Line Only)
When multi-line is necessary, method calls in a chain should be indented at the **same level as the scope they belong to**, not relative to the receiver or first method call.

### 3. Two-Space Indentation
Each scope level adds exactly **2 spaces** of indentation. This applies to:
- Method definitions inside classes/modules
- Code inside conditionals (`if`, `unless`, `case`)
- Code inside blocks (`each`, `map`, etc.)
- Code inside method calls with blocks

### 4. Consistent Chain Indentation (Multi-Line Only)
All method calls in a chain should have the **same indentation level**, determined by their scope.

## Examples

### Basic Method Chaining

```ruby
# ✅ BEST: Single line when possible
result = data.filter(&:valid?).map(&:transform).compact

# ✅ ACCEPTABLE: Multi-line only when line becomes too long or needs comments
result = very_long_variable_name_for_complex_data_structure
.filter { |item| item.meets_complex_validation_criteria? }  # Custom validation logic
.map { |item| item.transform_with_expensive_operation }     # CPU-intensive transform
.compact

# ❌ WRONG: Multi-line when single line would work fine
result = data
.filter(&:valid?)   # Unnecessary line break
.map(&:transform)
.compact

# ❌ WRONG: Double indentation when multi-line is actually needed
result = very_long_variable_name_for_complex_data_structure
    .filter { |item| item.meets_complex_validation_criteria? }   # Extra indentation
    .map { |item| item.transform_with_expensive_operation }
    .compact
```

### Inside Conditionals

```ruby
# ✅ BEST: Single line when possible
if complex_condition?
  result = user_data.select(&:active?).map(&:email).uniq
end

# ✅ ACCEPTABLE: Multi-line when necessary due to complexity
if user_requires_advanced_filtering_and_transformation?
  result = user_data_from_multiple_sources_requiring_complex_processing
  .select { |user| user.active? && user.verified? && user.has_permission?(:read) }
  .map { |user| generate_secure_email_with_encryption(user.email, encryption_key) }
  .reject { |email| email_blacklist.include?(email) || email.length > MAX_EMAIL_LENGTH }
  .uniq
end

# ❌ WRONG: Multi-line when single line would work
if complex_condition?
  result = user_data
  .select(&:active?)    # Unnecessary line break
  .map(&:email)
  .uniq
end

# ❌ WRONG: Double indentation when multi-line is actually needed
if user_requires_advanced_filtering_and_transformation?
  result = user_data_from_multiple_sources_requiring_complex_processing
      .select { |user| user.active? && user.verified? }  # Wrong: 6 spaces
      .map { |user| generate_secure_email_with_encryption(user.email) }
      .uniq
end
```

### Inside Blocks

```ruby
# ✅ BEST: Single line when possible  
users.each do |user|
  formatted_name = user.name.strip.downcase.gsub(/\s+/, "_")
  puts formatted_name
end

# ✅ ACCEPTABLE: Multi-line when necessary due to complexity
users_requiring_complex_name_processing.each do |user|
  formatted_name = user.full_name_with_titles_and_suffixes
  .strip                                    # Remove leading/trailing whitespace
  .gsub(/[[:space:]]+/, " ")               # Normalize internal whitespace  
  .gsub(/[^\w\s\-\.]/, "")                 # Remove special chars except dash/period
  .split(/\s+/)                            # Split into components
  .map { |part| part.length > 1 ? part.capitalize : part.upcase }  # Title case with acronym handling
  .join("_")                               # Join with underscores
  
  puts formatted_name
end

# ❌ WRONG: Multi-line when single line would work
users.each do |user|
  formatted_name = user.name
  .strip              # Unnecessary line break
  .downcase
  .gsub(/\s+/, "_")
end

# ❌ WRONG: Double indentation when multi-line is actually needed  
users_requiring_complex_name_processing.each do |user|
  formatted_name = user.full_name_with_titles_and_suffixes
      .strip                              # Wrong: 10 spaces
      .gsub(/[[:space:]]+/, " ")
      .gsub(/[^\w\s\-\.]/, "")
end
```

### Complex Nested Scopes

```ruby
# ✅ CORRECT: Prefer single-line, use multi-line only when necessary
class DataProcessor
  def process_users
    # Level 1: Class method scope (2 spaces) - single line when possible
    all_data = fetch_data.validate.normalize
    
    if all_data.any?
      # Level 2: Conditional scope (4 spaces) - multi-line when complexity requires it
      filtered_data = all_data_requiring_complex_business_logic_filtering
      .select { |item| item.active? && item.meets_compliance_requirements? }
      .reject { |item| item.expired? || item.flagged_by_security_scan? }
      .sort_by { |item| [item.priority_score, item.creation_date] }
      
      filtered_data.each do |item|
        # Level 3: Block scope (6 spaces) - single line when reasonable
        processed_item = item.transform.sanitize.save
        
        # Multi-line only when individual operations are complex
        audit_trail = item.audit_information_with_detailed_metadata
        .merge_with_user_context(current_user, request_context)
        .add_processing_timestamps(start_time, Time.current)
        .format_for_compliance_logging(regulatory_requirements)
        
        log_result(processed_item, audit_trail)
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
- **HEREDOC Cops**: RuboCop configured to catch HEREDOC structural errors

## HEREDOC Indentation Best Practices

HEREDOCs (Here Documents) require special attention to prevent structural indentation errors that can break Ruby syntax.

### Critical HEREDOC Rules

1. **Always use squiggly HEREDOC (`<<~`)** for proper indentation handling
2. **Content must be properly indented within the HEREDOC**
3. **Closing delimiter must align correctly**
4. **HEREDOC content follows the same 2-space indentation rules**

### Correct HEREDOC Formatting

```ruby
# ✅ CORRECT: Squiggly HEREDOC with proper indentation
def generate_template(file_path = "db/schema.yaml")
  template_content = <<~YAML
    # Enhanced Essence Schema
    schema_name: public
    
    defaults:
      "*":
        columns:
          id: ~
          created_at: ~
  YAML
  
  File.write(file_path, template_content)
end

# ✅ CORRECT: HEREDOC in migration content
def generate_migration_content(class_name, statements)
  content = <<~RUBY
    class #{class_name} < ActiveRecord::Migration[8.0]
      def up
  RUBY
  
  statements.each do |stmt|
    content += "    #{stmt}\n"
  end
  
  content += <<~RUBY
      end
      
      def down
        raise ActiveRecord::IrreversibleMigration
      end
    end
  RUBY
  
  content
end
```

### Common HEREDOC Mistakes

```ruby
# ❌ WRONG: Using regular HEREDOC without squiggly
def bad_example
  content = <<YAML
# This breaks indentation completely
schema_name: public
YAML
end

# ❌ WRONG: Improper indentation within HEREDOC
def another_bad_example
  template = <<~YAML
# This content is not properly indented
    schema_name: public
  defaults:
      "*":
    columns:
        id: ~
  YAML
end

# ❌ WRONG: Inconsistent indentation mixing
def terrible_example
  content = <<~RUBY
    class Migration < ActiveRecord::Migration
def up
      # Mixed indentation levels
    end
  end
  RUBY
end
```

### HEREDOC with Embedded Expressions

```ruby
# ✅ CORRECT: Proper use of embedded expressions
def generate_help_text(command)
  <<~HELP
    Usage: #{command} [options]
    
    Commands:
      generate    Generate migration
      apply       Apply schema changes
      preview     Preview changes
  HELP
end

# ✅ CORRECT: Complex HEREDOC with proper spacing
def generate_yaml_template
  template_content = <<~YAML
    schema_name: public
    
    defaults:
      "*":
        columns:
          id: ~
          created_at: ~
    #{'  '}
    # Pattern-based column inference
    column_patterns:
      - "^id$": "primary_key"
      - "_id$": "integer -> {table}.id"
  YAML
end
```

### RuboCop HEREDOC Cops

The following RuboCop cops catch HEREDOC structural errors:

- **`Layout/HeredocIndentation`**: Ensures proper indentation within HEREDOCs
- **`Layout/HeredocArgumentClosingParenthesis`**: Handles closing parenthesis placement  
- **`Lint/HeredocMethodCallPosition`**: Prevents method call positioning errors

These cops are essential for catching the fundamental structural errors that can break Ruby syntax.

### HEREDOC Debugging Tips

1. **Use `ruby -c filename.rb`** to check syntax after HEREDOC changes
2. **Look for "unexpected end-of-input" errors** - often indicate HEREDOC issues
3. **Check indentation consistency** within the HEREDOC content
4. **Verify closing delimiter alignment** 
5. **Test the output** - malformed HEREDOCs often produce garbled content

## Questions and Edge Cases

### Q: Should I always break method chains across multiple lines?
**A:** NO! Keep chains on a single line whenever reasonably possible. Only use multi-line when the single line becomes too long (120+ characters) or when you need inline comments to explain complex operations.

### Q: What about very long variable names?
**A:** Scope-based indentation is independent of variable name length. Always align with the scope level. But consider if long variable names are making single-line chains unnecessarily long.

### Q: What about assignment with complex right-hand sides?
**A:** Prefer single-line when possible. Use multi-line scope-based indentation only when necessary:
```ruby
# ✅ PREFERRED: Single line when reasonable
result = some_method_call(arg1, arg2).chain_method.another_method

# ✅ ACCEPTABLE: Multi-line only when single line is too long
complex_variable_name_here = some_complex_method_call_with_many_arguments(arg1, arg2, arg3)
.chain_method_with_complex_logic
.another_method_with_transformation
```

### Q: What about return statements?
**A:** Same rules apply - prefer single-line:
```ruby
# ✅ PREFERRED: Single line when reasonable
return user_data.select(&:active?).map(&:email).uniq

# ✅ ACCEPTABLE: Multi-line only when necessary
return user_data_from_complex_query_requiring_multiple_filters
.select { |user| user.active? && user.has_permission?(:email_access) }
.map { |user| encrypt_email_for_external_api(user.email) }
.uniq
```

---

## Summary

1. **Default to single-line method chains** whenever possible
2. **Use multi-line only when necessary** due to length or complexity
3. **When multi-line is needed**, use scope-based indentation (not double-indentation)
4. **Each scope level uses exactly 2 spaces** of indentation
5. **Method chains align with their scope level**, not with the receiver

This standard helps maintain clean, readable, and maintainable Ruby code across the entire project without forcing unnecessary line breaks.