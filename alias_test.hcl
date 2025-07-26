# Auto-generated HCL schema from alias_test.yaml
# Edit the YAML file and re-run the converter to update this file

schema "test" {}

table "users" {
  schema = schema.test
column "id" {
    null = false
    type = integer
    auto_increment = true
  }
primary_key {
  columns = [column.id]
}
}

