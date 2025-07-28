

## Interface ##

- [x] Rename Rake tasks from `atlas` namespace to `jaml` namespace.
- [x] Rename `yaml_to_hcl` to `convert`.
- [x] Add new column attribute inference patterns, such as `_on` for date columns.
- [ ] Enable column attribute concatenation, so that multiple patterns can be applied.
- [ ] Allow modification of details during the preview stage of
      edit → convert → preview → apply
- [ ] Validate YAML before processing
      Prompt: I want to add a validation step, to (1) make sure the YAML is well-formed and follows the structure we need, and (2) fix it if necessary and possible.  I would like to use RubySchema for this.



## Packaging ##

- [x] Wrap all this up as a gem, to be added to any Ruby project.


## Syntax ##

- [x] Change "schema_name" to "schema"
- [x] Change default schema from "main" to "public"
- [x] Support simpler syntax for column property patterns


## YAML ##

- [ ] Define a YAML schema using [RubySchema](https://github.com/yippee-fun/rubyschema) and ensure that all YAML used is valid before attempting to generate HCL with it
- [ ] Support specifying a non-default schema name in YAML
- [ ] Support combining multiple YAML files to create a single database
  - [ ] with multiple files all applying to the same schema
  - [ ] with one file per database schema
  - [ ] with arbitrary mapping of files to schemas


## Modeling ##

- [ ] Add the ability to create [table partials](https://community.dbdiagram.io/t/introducing-dbml-tablepartial-reuse-fields-reduce-repetition/4541)
- [ ] Add the ability to specify all missing constraints
- [ ] Add the ability to model views
- [ ] Add the ability to model materialized views
- [ ] Add the ability to model generated/computed columns


## Compilation ##

- [ ] Investigate & fix indentation failures in HCL files


## Guard ##

- [ ] Automatically run commands when schema.yaml is saved.

https://github.com/guard/guard


## Text Editors ##

- [ ] Create a Zed language server plugin for schema.yaml
- [ ] Create a VS Code "intellisense" plugin for schema.yaml
- [ ] Create a NeoVim language server plugin for schema.yaml
- [ ] Create a TextMate plugin (if possible) for schema.yaml


## DBML ##

https://github.com/holistics/dbml

- [ ] Add the ability to convert from YAML/JAML to [DBML](https://dbml.dbdiagram.io/home), possibly via [SQL](https://dbml.dbdiagram.io/cli) or from the [database](https://dbml.dbdiagram.io/cli#generate-dbml-directly-from-a-database)
- [ ] Add the ability to use [DBML](https://dbml.dbdiagram.io/home) instead of YAML/JAML as your composition language
- [ ] Add the ability to pull schemas to the [dbdiagram API](https://docs.dbdiagram.io/api/v1)
- [ ] Add the ability to push schemas (or parts of schemas) from the [dbdiagram API](https://docs.dbdiagram.io/api/v1)


## D2 ##

- [ ] Add the ability to generate D2 diagrams of your schemas.
- [ ] Add the ability to import D2 diagrams to create your tables.
https://github.com/zekenie/d2-erd-from-postgres

- [ ] Add the ability to generate D3 diagrams of your schemas.
- [ ] Add the ability to import D3 diagrams to create your tables.


# Documentation #

- [x] Normalize my terminology to be consistent with AML's terminology
      - use "attributes" to refer to columns
      - use "properties" to refer to the options on columns
- [ ] Document the differences between AML and Essence's YAML format
      https://azimutt.app/docs/aml
      https://azimutt.app/docs/aml/properties
      https://azimutt.app/docs/aml/identifiers
      https://azimutt.app/docs/aml/entities


## Partials ##

- [ ] Add support for partial YAML files that can be loaded by schema.yaml
- [ ] Add support for partial SQL files that can be loaded by schema.yaml
- [ ] Add support for partial Ruby files that can be loaded by schema.yaml
- [ ] Add support for other post-processing using Ruby, JavaScript, or shell scripts
  - [ ] triggered at the file level
  - [ ] triggered at the table level
