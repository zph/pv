require 'thor'
require 'tempfile'

$VERBOSE = nil

module Pv
  class Command < Thor
    include Thor::Actions
    class_option :stdout, type: :boolean

    default_task :log
    desc :log,  "Show every story assigned to you on this project."
    def log
      VCR.use_cassette('log') do
        stories = Pv.tracker.stories.sort_by! { |h| h.current_state }
        stories.each do |from_data|
          preview Story.new(from_data)
        end
      end
    end

    desc :label,  "Show every story for a label (excluding accepted stories)."
    def label(label = Pv.config.label)
      VCR.use_cassette("label_#{label}_label") do
        stories = Pv.tracker.stories_by_label(label)
        stories.reject { |i| i.accepted_at }.each do |from_data|
          preview Story.new(from_data)
        end
      end
    end

    desc "show STORY_ID", "Show the full text and attributes of a story on this project."
    def show story_id, output=STDOUT
      VCR.use_cassette("story_#{story_id}_show") do
        story = Story.find_any_by_id(story_id)
        full_render(story)
      end
    end

    desc "url STORY_ID", "Show the url to story on this project."
    def url story_id, output=STDOUT
      VCR.use_cassette("story_#{story_id}_url") do
        story = Story.find_any_by_id(story_id)
        output.puts story.url
      end
    end

    desc "open STORY_ID", "Open a sorty in a browser."
    def open story_id, output=STDOUT
      VCR.use_cassette("story_#{story_id}_open") do
        story = Story.find_any_by_id(story_id)
        `open #{story.url}`
      end
    end

    desc "branch STORY_ID", "Create git branch and checkout based on story ID and desc."
    def branch story_id, output=STDOUT

      VCR.use_cassette("story_#{story_id}_branch") do
        story = Story.find_any_by_id(story_id) or raise "Error: Story not found"
        initials = File.read(File.expand_path "~/.initials").split("\n").join("_")
        title = story.name.gsub(/[^A-Za-z0-9\/:\.,]/, '-').split(/\W+/).join('-').squeeze('-')
        a = ask "== Is the following title acceptable? {ENTER for yes}\n#{title}"
        unless a.empty? || a =~ /y/i
          title = ask "Enter a better title: > "
        end

        new_branch = [initials, story_id, title].join('_')

        check_for_branch = "git branch | grep #{new_branch}"
        if system(check_for_branch)
          puts "Branch: #{new_branch} already exists."
          command = "git checkout #{new_branch}"
        else
          command = "git checkout -b #{new_branch}"
        end

        system(command)
        full_render(story)

      end
    end

    desc "edit STORY_ID STATUS", "Edit a story's status on this project."
    def edit story_id, status
      VCR.use_cassette("story_#{story_id}_#{status}") do
        story = Story.find_any_by_id(story_id) or raise "Error: Story not found"

        if story.update(status)
          say "#{status.titleize} ##{story_id}"
        else
          say "Error: Story did not update."
        end
      end
    end

    %w(start finish deliver accept reject restart).each do |status|
      desc "#{status} STORY_ID", "#{status.titleize} a story on this project."
      define_method(status) do |story_id|

        VCR.use_cassette("story_#{story_id}_#{status}") do
          edit(story_id, "#{status}ed")
        end
      end

    end

    desc "create {bug|feature|chore} NAME", "Create a new story on this project"
    method_option :assign_to
    def create type, name
      with_attributes = options.merge(story_type: type, name: name)
      VCR.use_cassette("story_#{type}") do
        story = Story.create with_attributes

        if story.saved?
          say "Created #{type.titleize} ##{story.id}: '#{name}'"
        else
          say "Error saving #{type} with '#{name}'"
        end

      end
    end

    desc :help, "Show all commands"
    def help
      say IO.read("#{Pv.root}/lib/templates/help.txt")
      super
    end

    desc "open STORY_ID", "Open this Pivotal story in a browser"
    def open story_id
      run "open https://www.pivotaltracker.com/story/show/#{story_id}"
    end

  private
    no_tasks do
      def preview story
        transformer = options[:stdout] ? :plain_make : :make
          id = send(transformer, story.id, :YELLOW)
          author = send(transformer, story.requested_by, :cyan, true)
          status = if story.in_progress?
            send(transformer, " (#{story.current_state})", STATUS_COLORS[story.current_state.to_sym])
          else
            ""
          end

          leading_space = options[:stdout] ? "" : " "
          say ["#{leading_space}#{id}", status, story.name, author].join(send(transformer, " | ", :red, true ))
      end

      STATUS_COLORS = {
        started: :CYAN,
        finished: :BLUE,
        delivered: :GREEN,
        rejected: :RED,
      }

      def make(string, color, bold=false)
        set_color( string, Thor::Shell::Color.const_get(color.upcase.to_sym), bold)
      end

      def plain_make(string, color, bold=false)
        set_color( string, Thor::Shell::Color::WHITE, false)
      end

      def full_render story
        s = story
        transformer = options[:stdout] ? :plain_make : :make
          id = send(transformer, "#{s.id}", :yellow )
          points = send(transformer, "#{s.estimate} points", :red )
          author = send(transformer, s.requested_by, :white)
          status = story.in_progress? ? send(transformer, s.current_state, STATUS_COLORS[s.current_state.to_sym]) : ""
          requester = send(transformer, s.requested_by, :blue)
          owner = send(transformer, s.owned_by, :white)
          type = send(transformer, s.story_type.upcase, :red)
          name = send(transformer, s.name, :red)
          description = send(transformer, s.description, :white)

        temp = <<HERE
<%= "-"*60 %>
<%= type.titleize %>    <%= id %>   ( <%= points %> )
Status:          <%= status.rjust(25) %>
Requested By:    <%= requester.rjust(25) %>
Assigned To:     <%= owner.rjust(25) %>

<%= name %>

<%= description %>
<%= "-"*60 %>
HERE
        template = ERB.new(temp)
        say template.result(binding)

      end
    end
  end
end
