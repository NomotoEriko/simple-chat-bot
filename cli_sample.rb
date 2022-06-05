require_relative 'flow'

puts '会話を終了したい場合は quit を入力するか、Ctrl + C で処理を終了してください。'

user = 'user'
question, candidates = Flow.new(user).next_action
puts "#{question}: #{candidates.map(&:first).join(', ')}"
answer_text = gets.strip
while true do
  exit(0) if answer_text == 'quit'

  text_value = candidates.find do |(t, v)|
    t == answer_text
  end
  if text_value
    question, candidates = Flow.new(user, text_value[1]).next_action
    if candidates.count > 0
      puts "#{question}: #{candidates.map(&:first).join(', ')}\n>"
      answer_text = gets.strip
    else
      puts question
      exit(0)
    end
  else
    puts "#{candidates.map(&:first).join(', ')} の中から選んで返答してください。\n>"
    answer_text = gets.strip
  end
end
