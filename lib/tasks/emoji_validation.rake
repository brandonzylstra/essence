# frozen_string_literal: true

namespace :emoji do
  desc "Validate emoji mapping consistency and offer to fix issues"
  task :validate do
    require 'yaml'
    
    emoji_file = File.join(__dir__, '../../.git-emoji.yaml')
    
    unless File.exist?(emoji_file)
      puts "❌ Emoji mapping file not found: #{emoji_file}"
      exit 1
    end
    
    begin
      data = YAML.load_file(emoji_file)
    rescue Psych::SyntaxError => e
      puts "❌ Invalid YAML syntax: #{e.message}"
      exit 1
    end
    
    emojis = data['emojis'] || {}
    concepts = data['concepts'] || {}
    validation_rules = data['validation_rules'] || {}
    
    errors = []
    warnings = []
    fixes = []
    
    puts "🔍 Validating emoji mapping consistency..."
    puts
    
    # Check 1: Bidirectional consistency
    puts "1️⃣  Checking bidirectional consistency..."
    
    emojis.each do |emoji, emoji_data|
      primary_concept = emoji_data['primary']
      
      # Check if primary concept exists in concepts section
      if concepts[primary_concept]
        unless concepts[primary_concept]['primary']&.include?(emoji)
          errors << "❌ Emoji #{emoji} has primary concept '#{primary_concept}' but concept doesn't list this emoji as primary"
          fixes << "Add #{emoji} to concepts.#{primary_concept}.primary array"
        end
      else
        errors << "❌ Emoji #{emoji} has primary concept '#{primary_concept}' but concept doesn't exist in concepts section"
        fixes << "Add #{primary_concept} section to concepts with #{emoji} in primary array"
      end
      
      # Check contexts
      if emoji_data['contexts']
        emoji_data['contexts'].each do |context|
          context_concept = context['concept']
          if concepts[context_concept]
            # Context concepts can be in primary or secondary, but should exist somewhere
            found_in_primary = concepts[context_concept]['primary']&.include?(emoji)
            found_in_secondary = concepts[context_concept]['secondary']&.include?(emoji)
            
            unless found_in_primary || found_in_secondary
              warnings << "⚠️  Emoji #{emoji} has context '#{context_concept}' but concept doesn't reference this emoji"
              fixes << "Consider adding #{emoji} to concepts.#{context_concept}.secondary array"
            end
          else
            warnings << "⚠️  Emoji #{emoji} has context '#{context_concept}' but concept doesn't exist in concepts section"
            fixes << "Consider adding #{context_concept} section to concepts"
          end
        end
      end
    end
    
    # Check 2: Reverse consistency - concepts pointing to non-existent emojis
    puts "2️⃣  Checking reverse consistency..."
    
    concepts.each do |concept_name, concept_data|
      ['primary', 'secondary'].each do |type|
        next unless concept_data[type]
        
        concept_data[type].each do |emoji|
          unless emojis[emoji]
            errors << "❌ Concept '#{concept_name}' references emoji #{emoji} in #{type} but emoji doesn't exist in emojis section"
            fixes << "Either add #{emoji} to emojis section or remove from concepts.#{concept_name}.#{type}"
          end
        end
      end
    end
    
    # Check 3: Unique primary meanings
    puts "3️⃣  Checking for unique primary meanings..."
    
    primary_concepts = {}
    emojis.each do |emoji, emoji_data|
      primary = emoji_data['primary']
      if primary_concepts[primary]
        errors << "❌ Primary concept '#{primary}' is used by multiple emojis: #{primary_concepts[primary]} and #{emoji}"
        fixes << "Each emoji should have a unique primary meaning - consider making one secondary"
      else
        primary_concepts[primary] = emoji
      end
    end
    
    # Check 4: Validation rules compliance
    puts "4️⃣  Checking validation rules compliance..."
    
    if validation_rules['max_contexts_per_emoji']
      max_contexts = validation_rules['max_contexts_per_emoji']
      emojis.each do |emoji, emoji_data|
        contexts_count = emoji_data['contexts']&.length || 0
        if contexts_count > max_contexts
          warnings << "⚠️  Emoji #{emoji} has #{contexts_count} contexts, exceeding limit of #{max_contexts}"
          fixes << "Consider reducing contexts for #{emoji} to #{max_contexts} or fewer"
        end
      end
    end
    
    if validation_rules['require_usage_description']
      emojis.each do |emoji, emoji_data|
        if emoji_data['contexts']
          emoji_data['contexts'].each do |context|
            unless context['usage']
              warnings << "⚠️  Emoji #{emoji} context '#{context['concept']}' missing usage description"
              fixes << "Add usage description for #{emoji} context '#{context['concept']}'"
            end
          end
        end
      end
    end
    
    # Check 5: Orphaned concepts
    puts "5️⃣  Checking for orphaned concepts..."
    
    used_concepts = Set.new
    emojis.each do |emoji, emoji_data|
      used_concepts.add(emoji_data['primary'])
      if emoji_data['contexts']
        emoji_data['contexts'].each do |context|
          used_concepts.add(context['concept'])
        end
      end
    end
    
    concepts.each_key do |concept_name|
      unless used_concepts.include?(concept_name)
        warnings << "⚠️  Concept '#{concept_name}' is defined but not used by any emoji"
        fixes << "Consider removing unused concept '#{concept_name}' or assign it to an emoji"
      end
    end
    
    # Display results
    puts
    puts "📊 Validation Results:"
    puts "=" * 50
    
    if errors.empty? && warnings.empty?
      puts "✅ All validations passed! Emoji mapping is consistent."
    else
      if errors.any?
        puts "🚨 ERRORS (#{errors.length}):"
        errors.each { |error| puts "   #{error}" }
        puts
      end
      
      if warnings.any?
        puts "⚠️  WARNINGS (#{warnings.length}):"
        warnings.each { |warning| puts "   #{warning}" }
        puts
      end
      
      if fixes.any?
        puts "🔧 SUGGESTED FIXES:"
        fixes.each_with_index { |fix, i| puts "   #{i + 1}. #{fix}" }
        puts
      end
      
      if errors.any?
        puts "❌ Validation failed with #{errors.length} error(s)."
        exit 1
      else
        puts "⚠️  Validation completed with #{warnings.length} warning(s)."
      end
    end
    
    # Statistics
    puts
    puts "📈 Statistics:"
    puts "   Emojis defined: #{emojis.length}"
    puts "   Concepts defined: #{concepts.length}"
    puts "   Total contexts: #{emojis.values.sum { |data| data['contexts']&.length || 0 }}"
    puts "   Average contexts per emoji: #{'%.1f' % (emojis.values.sum { |data| data['contexts']&.length || 0 }.to_f / emojis.length)}"
  end
  
  desc "Show emoji usage statistics and patterns"
  task :stats do
    require 'yaml'
    
    emoji_file = File.join(__dir__, '../../.git-emoji.yaml')
    data = YAML.load_file(emoji_file)
    emojis = data['emojis'] || {}
    concepts = data['concepts'] || {}
    
    puts "📊 Emoji Mapping Statistics"
    puts "=" * 40
    puts
    
    # Most complex emojis (most contexts)
    complex_emojis = emojis.sort_by { |_, data| -(data['contexts']&.length || 0) }.first(5)
    puts "🧩 Most Complex Emojis (most contexts):"
    complex_emojis.each do |emoji, data|
      context_count = data['contexts']&.length || 0
      puts "   #{emoji} (#{data['primary']}) - #{context_count} contexts"
    end
    puts
    
    # Most popular concepts (referenced by most emojis)
    concept_popularity = concepts.map do |name, data|
      total_refs = (data['primary']&.length || 0) + (data['secondary']&.length || 0)
      [name, total_refs]
    end.sort_by { |_, count| -count }.first(5)
    
    puts "🌟 Most Popular Concepts:"
    concept_popularity.each do |concept, count|
      puts "   #{concept} - #{count} emoji(s)"
    end
    puts
    
    # Concepts with only secondary emojis
    secondary_only = concepts.select { |_, data| data['primary'].nil? || data['primary'].empty? }
    if secondary_only.any?
      puts "🔄 Concepts with only secondary emojis:"
      secondary_only.each { |concept, _| puts "   #{concept}" }
      puts
    end
    
    # Distribution of contexts per emoji
    context_distribution = Hash.new(0)
    emojis.each do |_, data|
      count = data['contexts']&.length || 0
      context_distribution[count] += 1
    end
    
    puts "📊 Context Distribution:"
    context_distribution.sort.each do |count, emoji_count|
      bar = "█" * (emoji_count * 20 / emojis.length)
      puts "   #{count} contexts: #{emoji_count} emojis #{bar}"
    end
  end
  
  desc "Interactive emoji lookup and search"
  task :search do
    require 'yaml'
    
    emoji_file = File.join(__dir__, '../../.git-emoji.yaml')
    data = YAML.load_file(emoji_file)
    emojis = data['emojis'] || {}
    concepts = data['concepts'] || {}
    
    puts "🔍 Interactive Emoji Search"
    puts "Enter a concept, emoji, or partial match (or 'quit' to exit):"
    puts
    
    loop do
      print "> "
      input = $stdin.gets&.chomp
      break if input.nil? || input.downcase == 'quit'
      
      if input.empty?
        puts "Please enter a search term."
        next
      end
      
      # Direct emoji lookup
      if emojis[input]
        data = emojis[input]
        puts "#{input} - #{data['primary']}"
        if data['contexts']
          data['contexts'].each do |context|
            puts "  └─ #{context['concept']}: #{context['usage']}"
          end
        end
        puts
        next
      end
      
      # Direct concept lookup
      if concepts[input]
        data = concepts[input]
        puts "Concept: #{input}"
        if data['primary']
          puts "  Primary: #{data['primary'].join(', ')}"
        end
        if data['secondary']
          puts "  Secondary: #{data['secondary'].join(', ')}"
        end
        puts
        next
      end
      
      # Fuzzy search
      matches = []
      
      # Search in emoji primary concepts
      emojis.each do |emoji, emoji_data|
        if emoji_data['primary'].include?(input.downcase)
          matches << "#{emoji} (primary: #{emoji_data['primary']})"
        end
        
        if emoji_data['contexts']
          emoji_data['contexts'].each do |context|
            if context['concept'].include?(input.downcase) || context['usage']&.include?(input.downcase)
              matches << "#{emoji} (context: #{context['concept']} - #{context['usage']})"
            end
          end
        end
      end
      
      # Search in concept names
      concepts.each do |concept_name, concept_data|
        if concept_name.include?(input.downcase)
          emoji_list = (concept_data['primary'] || []) + (concept_data['secondary'] || [])
          matches << "Concept: #{concept_name} (#{emoji_list.join(', ')})"
        end
      end
      
      if matches.any?
        puts "Found #{matches.length} match(es):"
        matches.first(10).each { |match| puts "  #{match}" }
        puts "  ..." if matches.length > 10
      else
        puts "No matches found for '#{input}'"
      end
      puts
    end
    
    puts "Goodbye! 👋"
  end
end