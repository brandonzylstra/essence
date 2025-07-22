# Event Types for Speech & Debate Tournaments

EventType.find_or_create_by(name: 'Persuasive Speaking') do |event|
  event.abbreviation = 'PERS'
  event.category = 'speech'
  event.participant_type = 'individual'
  event.max_participants_per_match = 8
  event.description = 'A speech designed to convince the audience of a particular viewpoint'
end

EventType.find_or_create_by(name: 'Informative Speaking') do |event|
  event.abbreviation = 'INFO'
  event.category = 'speech'
  event.participant_type = 'individual'
  event.max_participants_per_match = 8
  event.description = 'A speech that educates the audience about a specific topic'
end

EventType.find_or_create_by(name: 'Original Oratory') do |event|
  event.abbreviation = 'OO'
  event.category = 'speech'
  event.participant_type = 'individual'
  event.max_participants_per_match = 8
  event.description = 'An original speech on a topic of the speaker\'s choosing'
end

EventType.find_or_create_by(name: 'Duo Interpretation') do |event|
  event.abbreviation = 'DUO'
  event.category = 'interpretation'
  event.participant_type = 'team'
  event.max_participants_per_match = 8
  event.description = 'A dramatic performance by two people'
end

EventType.find_or_create_by(name: 'Team Policy Debate') do |event|
  event.abbreviation = 'TP'
  event.category = 'debate'
  event.participant_type = 'team'
  event.max_participants_per_match = 2
  event.description = 'A debate format with two-person teams arguing policy resolutions'
end

EventType.find_or_create_by(name: 'Lincoln Douglas Debate') do |event|
  event.abbreviation = 'LD'
  event.category = 'debate'
  event.participant_type = 'individual'
  event.max_participants_per_match = 2
  event.description = 'A one-on-one debate format focusing on value and philosophical arguments'
end

EventType.find_or_create_by(name: 'Apologetics') do |event|
  event.abbreviation = 'APOL'
  event.category = 'speech'
  event.participant_type = 'individual'
  event.max_participants_per_match = 8
  event.description = 'A defense of the Christian faith in response to questions'
end
