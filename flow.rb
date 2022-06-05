class Flow
  class MmdParser
    class InvalidGraphType < StandardError; end
    class NodeNotFound < StandardError; end
    class ChildOfRootShouldBeJustOne < StandardError; end

    Node = Struct.new(:surface, :key, :id)
    Edge = Struct.new(:src, :dst, :action)
    DEFAULT_EDGE_LABEL = 'next'

    def initialize(file)
      @file = file
    end

    def parse
      # STATES = {
      #   0 => [['YES', 1], ['NO', 2]],
      #   1 => [['YES', 3], ['NO', 4]],
      #   2 => [],
      #   3 => [],
      #   4 => []
      # }
      # TEXT = {
      #   0 => '直近3時間以内に<br />コーヒーを飲む以外のことを<br />何もしない時間があった',
      #   1 => '自分が手をつけている仕事で<br />他の人に引き渡せない状態のものがある',
      #   2 => '休め',
      #   3 => 'がんばれ',
      #   4 => '新しいタスクとれ'
      # }
      validate_graph_type

      states = edges.inject(Hash.new{|hash, key| hash[key] = []}) do |result, edge|
        result[edge.src] << [edge.action, edge.dst]
        result
      end
      text = nodes.to_h do |node|
        [node.id, node.surface.gsub('<br />', '').gsub('<br/>', '')]
      end

      root_node = find_node('emp', false)
      child_of_root = edges.select do |edge|
        edge.src == root_node.id
      end
      raise ChildOfRootShouldBeJustOne unless child_of_root.count == 1
      first_state = child_of_root.first.dst

      [first_state, states, text]
    end

    private

    def validate_graph_type
      raise InvalidGraphType unless File.open(@file, 'r').first.match?('graph TD')
    end

    def nodes
      return @nodes if @nodes

      cursor = -1
      @nodes = File.open(@file, 'r').each_line.drop(1).map do |line|
        if m = line.match(/([a-zA-Z]+)\(\[?(.+?)\]?\)/)
          cursor += 1
          Node.new(m[2], m[1], cursor)
        elsif m = line.match(/([a-zA-Z]+)\[(.+?)\]/)
          cursor += 1
          Node.new(m[2], m[1], cursor)
        end
      end.compact
    end

    def edges
      return @edges if @edges
      @edges = File.open(@file, 'r').each_line.drop(1).map do |line|
        if m = line.match(/([a-zA-Z]+) ?-- ?(.+?) ?--> ?([a-zA-Z]+)/)
          src_node = find_node(m[1])
          dst_node = find_node(m[3])
          Edge.new(src_node.id, dst_node.id, m[2])
        elsif m = line.match(/([a-zA-Z]+) ?--> ?([a-zA-Z]+)/)
          src_node = find_node(m[1])
          dst_node = find_node(m[2])
          Edge.new(src_node.id, dst_node.id, DEFAULT_EDGE_LABEL)
        end
      end.compact
    end

    def find_node(key, append_node_unless_exists=true)
      node = nodes.find do |n|
        n.key == key
      end
      return node if node

      raise NodeNotFound unless append_node_unless_exists
      node = Node.new(key, key, @nodes.count)
      nodes << node
      node
    end
  end

  DELIMITER = '_'
  FIRST_STATE, STATES, TEXT = Flow::MmdParser.new('graph.mmd').parse

  def initialize(user, value=nil)
    # NOTE: value に何もない場合は初期状態を作る
    value = [FIRST_STATE, nil, user].join(DELIMITER) unless value
    self.class.validate_user!(user, value)
    @user = user
    @question_id, @answer = self.class.parse_value(value)
  end

  def next_action
    responce_text = TEXT[@question_id]
    next_values = STATES[@question_id].map do |answer, state_id|
        [answer, [state_id, answer, @user].join(DELIMITER)]
    end
    [responce_text, next_values]
  end

  def self.parse_value(value)
    first_delim = value.index(DELIMITER)
    second_delim = value.index(DELIMITER, first_delim.succ)
    question_id = value[0...first_delim].to_i
    answer = value[first_delim.succ...second_delim]
    user = value[second_delim.succ..]

    [question_id, answer, user]
  end

  def self.validate_user!(user, value)
    _, _, u = parse_value(value)
    raise unless user == u
  end
end
