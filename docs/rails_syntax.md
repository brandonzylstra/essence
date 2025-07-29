# Using Rails Syntax in Essence

This guide shows how to use Rails migration syntax in Essence schemas alongside or instead of Atlas/SQL syntax.

## Syntax Options

Essence supports both syntaxes simultaneously:
- **Atlas/SQL syntax**: `name: string(100) not_null`
- **Rails syntax**: `name: :string, limit: 100, null: false`
- **Mixed approach**: Use both in the same schema

## Implementation Approaches

### Approach 1: Table-by-Table Syntax Choice

**Best for**: Large schemas, teams wanting consistency per table

Use different syntax for different tables:

```yaml
tables:
  users:  # Rails syntax
    columns:
      name: :string, limit: 100, null: false
      email: :string, limit: 255, null: false, unique: true
      active: :boolean, default: true
  
  posts:  # Atlas/SQL syntax
    columns:
      title: string(255) not_null
      content: text
      user_id: ~
```

### Approach 2: Mixed Syntax Within Tables

**Best for**: Teams wanting to use Rails syntax for complex types only

```yaml
tables:
  products:
    columns:
      name: string(255) not_null                    # Atlas/SQL syntax
      price: :decimal, precision: 10, scale: 2     # Rails syntax
      category: string(50)                         # Atlas/SQL syntax
      metadata: :json                              # Rails-specific type
```

### Approach 3: Rails Syntax Throughout

**Best for**: Teams fully comfortable with Rails syntax

Use Rails syntax for entire schema:

```yaml
tables:
  users:
    columns:
      id: primary_key  # Special Atlas type
      name: :string, limit: 100, null: false
      email: :string, limit: 255, null: false, unique: true
      created_at: :datetime, null: false
      updated_at: :datetime, null: false
```

## Syntax Comparison Reference

### Basic Types

| **Atlas/SQL** | **Rails Equivalent** |
|-------------|---------------------|
| `string(100)` | `:string, limit: 100` |
| `string(100) not_null` | `:string, limit: 100, null: false` |
| `integer` | `:integer` |
| `integer not_null` | `:integer, null: false` |
| `text` | `:text` |
| `boolean` | `:boolean` |
| `boolean default=true` | `:boolean, default: true` |
| `datetime` | `:datetime` |
| `datetime not_null` | `:datetime, null: false` |
| `date` | `:date` |
| `decimal(10,2)` | `:decimal, precision: 10, scale: 2` |

### Complex Examples

```yaml
# Atlas/SQL syntax
users:
  columns:
    email: string(255) not_null unique
    age: integer not_null
    salary: decimal(10,2) default=0.00
    bio: text
    active: boolean default=true not_null
    created_at: datetime not_null

# Rails syntax equivalent
users:
  columns:
    email: :string, limit: 255, null: false, unique: true
    age: :integer, null: false
    salary: :decimal, precision: 10, scale: 2, default: 0.00
    bio: :text
    active: :boolean, default: true, null: false
    created_at: :datetime, null: false
```

## Type Conversion Process

### Converting Between Syntaxes

Use this conversion reference:

#### For Each Column:
1. **Base type**: `string` ↔ `:string`
2. **Size constraints**: `(100)` ↔ `, limit: 100`
3. **Null constraints**: `not_null` ↔ `, null: false`
4. **Defaults**: `default=true` ↔ `, default: true`
5. **Unique constraints**: `unique` ↔ `, unique: true`

#### Example Conversions:
```yaml
# Atlas/SQL syntax
name: string(100) not_null unique

# Rails syntax equivalent
name: :string, limit: 100, null: false, unique: true
```

### Testing Your Schema

```bash
# Compile to verify syntax
rake essence:compile

# Preview changes
rake essence:preview

# Apply changes
rake essence:apply
```

## Common Usage Patterns

### Foreign Keys

Foreign keys work identically with pattern matching:

```yaml
# Both syntaxes work with patterns
user_id: ~  # Becomes foreign key to users.id

# Or explicit Rails syntax
user_id: :integer, null: false, foreign_key: { to_table: :users }
```

### Timestamps

```yaml
# Atlas/SQL syntax
created_at: datetime not_null
updated_at: datetime not_null

# Rails syntax options
created_at: :datetime, null: false
# OR
created_at: :timestamp  # Rails :timestamp maps to datetime
```

### Indexes

Indexes remain in the Atlas format regardless of column syntax:

```yaml
users:
  columns:
    email: :string, limit: 255, null: false  # Rails syntax
    name: string(100) not_null                # Atlas/SQL syntax
  indexes:
    - email        # Index syntax stays the same
    - name
    - columns: [email, name]
      unique: true
```

## Advanced Usage Scenarios

### Complex Constraints

```yaml
# Atlas/SQL syntax
price: decimal(10,2) not_null default=0.00

# Rails syntax equivalent
price: :decimal, precision: 10, scale: 2, null: false, default: 0.00
```

### Using Pattern Matching

Pattern matching works with both syntaxes:

```yaml
column_patterns:
  - "_id$": "integer -> {table}.id on_delete=cascade not_null"
  - "_at$": "datetime not_null"
  - "is_*": "boolean default=false not_null"

tables:
  posts:
    columns:
      title: :string, limit: 255    # Rails syntax
      user_id: ~                    # Pattern still works
      published_at: ~               # Pattern still works
```

### Database-Specific Types

Rails syntax supports database-specific types:

```yaml
# PostgreSQL-specific types
analytics:
  columns:
    id: :uuid, primary_key: true
    data: :jsonb
    coordinates: :point
    search_terms: :text, array: true
```

## Troubleshooting

### Common Issues

#### Issue: Syntax Error
```yaml
# Problem: Missing colons in Rails syntax
name: string, limit: 100

# Solution: Use colon for Rails syntax
name: :string, limit: 100
```

#### Issue: Pattern Matching Not Working
```yaml
# Problem: Using Rails syntax in patterns
column_patterns:
  - "_id$": ":integer, foreign_key: true"  # ❌ Wrong

# Solution: Patterns use Atlas/SQL syntax
column_patterns:
  - "_id$": "integer -> {table}.id on_delete=cascade not_null"  # ✅ Correct
```

#### Issue: Mixed Syntax in Same Column
```yaml
# Problem: Mixing syntaxes in one column
name: string(100), null: false  # ❌ Mixed syntax

# Solution: Choose one syntax per column
name: string(100) not_null      # ✅ Atlas/SQL syntax
# OR
name: :string, limit: 100, null: false  # ✅ Rails syntax
```

### Validation

Always validate your schema:

```bash
# Check compilation
rake essence:compile

# Verify generated HCL
cat db/schema.hcl

# Preview database changes
rake essence:preview
```

## Best Practices

### 1. Document Your Choice

Add a comment to your schema explaining the syntax approach:

```yaml
# Using Rails migration syntax
# Pattern matching uses Atlas/SQL syntax
schema_name: public

tables:
  users:
    columns:
      name: :string, limit: 100, null: false
```

### 2. Train Your Team

Ensure team members understand both syntaxes:

```yaml
# Good: Document complex examples
products:
  columns:
    # Standard Rails syntax
    name: :string, limit: 255, null: false
    
    # PostgreSQL-specific type
    metadata: :jsonb
    
    # Pattern-matched foreign key (uses Atlas/SQL patterns)
    category_id: ~
```

### 3. Consistent Style Within Files

Choose a primary syntax per file or table:

```yaml
# Rails syntax focus
users:
  columns:
    name: :string, limit: 100, null: false
    email: :string, limit: 255, null: false, unique: true
    league_id: ~  # Pattern matching

# Atlas/SQL syntax focus
teams:
  columns:
    name: string(255) not_null
    active: boolean default=true
    league_id: ~  # Pattern matching
```

### 4. Choose Syntax by Use Case

Use Rails syntax for:
- Database-specific types (`:jsonb`, `:uuid`)
- Complex constraints
- Explicit option specification

Use Atlas/SQL syntax for:
- Simple, common types
- Concise definitions
- Quick prototyping

## Schema Development Checklist

- [ ] **Choose syntax approach**
- [ ] **Document syntax choice**
- [ ] **Test compilation**: `rake essence:compile`
- [ ] **Preview changes**: `rake essence:preview`
- [ ] **Train team on syntax**
- [ ] **Establish style guidelines**

## Getting Help

### Common Questions

**Q: Do I have to use Rails syntax?**
A: No, Rails syntax is completely optional. Both syntaxes work equally well.

**Q: Can I mix syntaxes?**
A: Yes, you can mix within the same file or even the same table.

**Q: Do patterns work with Rails syntax?**
A: Yes, patterns work identically regardless of column syntax.

**Q: What about performance?**
A: No performance difference - both compile to identical HCL/SQL.

### Resources

- [Data Types Documentation](data_types.md)
- [Pattern Matching Guide](../README.md#-available-patterns-)
- [Rails Migration Reference](https://api.rubyonrails.org/classes/ActiveRecord/Migration.html)

## Summary

Rails syntax support in Essence is:
- **Optional** - use it when it adds value
- **Flexible** - mix syntaxes as needed
- **Powerful** - access to Rails-specific types and options
- **Compatible** - works with all Essence features

Choose the syntax approach that works best for your team and project needs.