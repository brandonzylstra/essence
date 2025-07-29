# Data Types in Essence

Essence provides a flexible data type system that accepts both Atlas/SQL-derived types and Rails migration types, making it easy for developers to use familiar syntax while providing the power of Atlas HCL compilation.

## Overview

Essence acts as a bridge between different type systems:

```
YAML Schema (Atlas/Rails types) → HCL/Atlas types → Rails Migration types → SQL types
```

This flexibility means you can write schemas using either:
- **Atlas/SQL types** (`string`, `integer`, `boolean`, etc.)
- **Rails migration types** (`:string`, `:integer`, `:boolean`, etc.)
- **Mixed approach** (use both as needed)

## Supported Data Types

### Core Types (Both Syntaxes Supported)

| **Atlas/SQL Type** | **Rails Type** | **HCL/Atlas Type** | **Example Usage** |
|-------------------|----------------|-------------------|-------------------|
| `string` | `:string` | `varchar` | `name: string(100)` or `name: :string, limit: 100` |
| `text` | `:text` | `text` | `description: text` or `description: :text` |
| `integer` | `:integer` | `integer` | `age: integer` or `age: :integer` |
| `boolean` | `:boolean` | `boolean` | `active: boolean` or `active: :boolean` |
| `datetime` | `:datetime` | `datetime` | `created_at: datetime` or `created_at: :datetime` |
| `date` | `:date` | `date` | `birth_date: date` or `birth_date: :date` |
| `decimal` | `:decimal` | `decimal` | `price: decimal(10,2)` or `price: :decimal, precision: 10, scale: 2` |
| `binary` | `:binary` | `binary` | `data: binary` or `data: :binary` |

### Extended Types

| **Atlas/SQL Type** | **Rails Type** | **HCL/Atlas Type** | **Notes** |
|-------------------|----------------|-------------------|-----------|
| `bigint` | `:bigint` | `bigint` | Large integers |
| `float` | `:float` | `float` | Floating point numbers |
| `datetime` | `:timestamp` | `datetime` | Rails `:timestamp` maps to `datetime` |
| `time` | `:time` | `time` | Time without date |

### Special Types

| **Type** | **Usage** | **Result** |
|----------|-----------|------------|
| `primary_key` | `id: primary_key` | Auto-incrementing primary key |
| `~` | `column_name: ~` | Inferred from pattern matching |

## Usage Examples

### Atlas/SQL Syntax

```yaml
tables:
  users:
    columns:
      id: primary_key
      name: string(100) not_null
      email: string(255) not_null unique
      age: integer
      bio: text
      active: boolean default=true
      salary: decimal(10,2)
      created_at: datetime not_null
      updated_at: datetime not_null
```

### Rails Migration Syntax

```yaml
tables:
  users:
    columns:
      id: primary_key
      name: :string, limit: 100, null: false
      email: :string, limit: 255, null: false, unique: true
      age: :integer
      bio: :text
      active: :boolean, default: true
      salary: :decimal, precision: 10, scale: 2
      created_at: :datetime, null: false
      updated_at: :datetime, null: false
```

### Mixed Syntax

```yaml
tables:
  users:
    columns:
      id: primary_key
      name: string(100) not_null        # Atlas/SQL syntax
      email: :string, limit: 255        # Rails syntax
      age: integer                      # Atlas/SQL syntax
      bio: :text                        # Rails syntax
      active: boolean default=true      # Atlas/SQL syntax
      created_at: :datetime             # Rails syntax
      updated_at: datetime not_null     # Atlas/SQL syntax
```

## Pattern Matching with Both Syntaxes

Pattern matching works identically with both syntaxes:

```yaml
column_patterns:
  - "_id$": "integer -> {table}.id on_delete=cascade not_null"
  - "_at$": "datetime not_null"
  - "is_*": "boolean default=false not_null"

tables:
  posts:
    columns:
      title: string(255)           # Atlas/SQL syntax
      user_id: ~                   # Pattern: foreign key to users.id
      published_at: ~              # Pattern: datetime not_null
      is_featured: ~               # Pattern: boolean default=false not_null
      
  comments:
    columns:
      content: :text               # Rails syntax
      post_id: ~                   # Pattern: foreign key to posts.id
      created_at: ~                # Pattern: datetime not_null
      is_approved: ~               # Pattern: boolean default=false not_null
```

## Type Conversion Flow

### YAML to HCL Conversion

When you run `rake essence:compile`, types are normalized:

1. **Rails types** are converted to **Atlas equivalents**:
   - `:string` → `string`
   - `:timestamp` → `datetime`
   - `:bigint` → `bigint`

2. **Atlas types** are converted to **HCL types**:
   - `string` → `varchar`
   - `datetime` → `datetime`
   - `boolean` → `boolean`

### HCL to Rails Migration Conversion

When generating Rails migrations, HCL types map back:

```ruby
# Generated migration uses Rails types
add_column :users, :name, :string, limit: 100, null: false
add_column :users, :created_at, :datetime, null: false
add_column :users, :active, :boolean, default: true
```

## Best Practices

### 1. Choose Your Primary Syntax

Choose the syntax that works best for your team:
- Use **Rails syntax** if your team is familiar with Rails migrations
- Use **Atlas/SQL syntax** for more concise definitions
- Both syntaxes can be used together in the same schema

### 2. Consistency Within Tables

```yaml
# Good: Consistent within table
users:
  columns:
    name: string(100) not_null
    email: string(255) not_null unique
    active: boolean default=true

# Also Good: Consistent within table  
posts:
  columns:
    title: :string, limit: 255, null: false
    content: :text
    published: :boolean, default: false
```

### 3. Mixed Syntax Guidelines

When mixing syntaxes in the same table:
- Use **Atlas/SQL syntax** for simple types: `integer`, `boolean`, `text`
- Use **Rails syntax** when you need complex options: `:decimal, precision: 10, scale: 2`

```yaml
products:
  columns:
    name: string(255) not_null              # Simple - Atlas/SQL syntax
    price: :decimal, precision: 10, scale: 2  # Complex - Rails syntax
    active: boolean default=true             # Simple - Atlas/SQL syntax
    metadata: :json                          # Rails-specific type
```

## Syntax Examples

### Atlas/SQL Syntax Example

```yaml
tables:
  users:
    columns:
      name: string(100) not_null
      active: boolean default=true
```

### Rails Syntax Example

```yaml
tables:
  users:
    columns:
      name: :string, limit: 100, null: false
      email: :string, limit: 255, null: false, unique: true
```

## Type System Architecture

### Why This Flexibility?

1. **Rails Developer Familiarity**: Rails developers can immediately use syntax they know
2. **Atlas Power**: Leverage Atlas's robust schema management
3. **Best of Both Worlds**: Combine Atlas's concise syntax with Rails' explicit options
4. **Database Compatibility**: Easy to add new Rails-specific types as they're introduced

### Atlas/HCL Relationship

The current data types are based on Atlas usage. Atlas types are in turn based on SQL standard types, with some database-specific extensions.

**The conversion flow:**
```
Your YAML → Essence Normalization → Atlas HCL → Database SQL
```

This ensures maximum database compatibility while providing a clean, developer-friendly interface.

## Advanced Usage

### Database-Specific Types

For PostgreSQL-specific types:

```yaml
tables:
  analytics:
    columns:
      id: :uuid                    # PostgreSQL UUID
      data: :jsonb                 # PostgreSQL JSONB
      search_vector: :tsvector     # PostgreSQL full-text search
```

## Complete Example Schema

Here's a comprehensive example showing all syntax options working together:

```yaml
schema_name: public

defaults:
  "*":
    columns:
      id: primary_key
      created_at: datetime not_null
      updated_at: datetime not_null

column_patterns:
  - "_id$": "integer -> {table}.id on_delete=cascade not_null"
  - "_at$": "datetime not_null"
  - "is_*": "boolean default=false not_null"
  - "*_count": "integer default=0 not_null"
  - "*_email": "string(255)"

tables:
  # Atlas/SQL syntax
  users:
    columns:
      first_name: string(100) not_null
      last_name: string(100) not_null
      email: string(255) not_null unique
      is_active: boolean default=true
      login_count: ~          # Pattern: integer default=0
      company_id: ~           # Pattern: foreign key
      last_login_at: ~        # Pattern: datetime not_null

  # Rails syntax
  products:
    columns:
      name: :string, limit: 255, null: false
      description: :text
      price: :decimal, precision: 10, scale: 2
      inventory_count: :integer, default: 0, null: false
      is_featured: :boolean, default: false
      category_id: ~          # Pattern works with Rails syntax
      created_at: :timestamp, null: false

  # Mixed syntax
  orders:
    columns:
      order_number: string(50) not_null unique    # Atlas/SQL
      total_amount: :decimal, precision: 12, scale: 2  # Rails
      notes: text                                 # Atlas/SQL
      metadata: :jsonb                           # Rails (PostgreSQL)
      user_id: ~                                 # Pattern
      shipped_at: ~                              # Pattern

  # Pattern resolution tables
  companies:
    columns:
      name: string(255) not_null
      contact_email: ~        # Pattern: string(255)
      employee_count: ~       # Pattern: integer default=0
      is_public: ~           # Pattern: boolean default=false

  categories:
    columns:
      name: :string, limit: 100, null: false
      parent_id: integer -> categories.id on_delete=cascade
      is_active: ~           # Pattern works with explicit definitions
```

This example demonstrates:
- **Atlas/SQL syntax**: Concise type definitions
- **Rails syntax**: Explicit constraints and database-specific types
- **Pattern matching**: Works with both syntaxes seamlessly
- **Mixed usage**: Different tables can use different approaches
- **Foreign keys**: Automatic pattern resolution and explicit definitions
- **Database types**: PostgreSQL-specific `:jsonb` type

## Summary

Essence's flexible data type system provides:
- **Dual syntax support** for Atlas/SQL and Rails migration types
- **Pattern matching** that works with both syntaxes
- **Database compatibility** through Atlas HCL compilation
- **Team flexibility** to choose the approach that works best

Choose the syntax that works best for your team, or mix both as needed. The underlying power of Atlas HCL compilation and Rails integration remains the same.