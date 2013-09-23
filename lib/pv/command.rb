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
      Pv.tracker.stories.each do |from_data|
        preview Story.new(from_data)
      end
    end

    desc "show STORY_ID", "Show the full text and attributes of a story on this project."
    def show story_id, output=STDOUT
      story = Story.find_any_by_id(story_id)
      full_render(story)
    end

    desc "branch STORY_ID", "Create git branch and checkout based on story ID and desc."
    def branch story_id, output=STDOUT
      story = Story.find_any_by_id(story_id) or raise "Error: Story not found"
      initials = File.read(File.expand_path "~/.initials").split("\n").join("_")
      title = story.name.gsub(/[^A-Za-z0-9\/:\.,]/, '-').split(/\W+/).join('-').squeeze('-')
      a = ask "== Is the following title acceptable? {ENTER for yes}\n#{title}"
      unless a.empty? || a =~ /y/i
        title = ask "Enter a better title: > "
      end

      command = "git checkout -b #{[initials, story_id, title].join('_')}"

      system(command)
      full_render(story)
    end

    desc "edit STORY_ID STATUS", "Edit a story's status on this project."
    #method_option :message, default: "", alias: 'm'
    def edit story_id, status
      story = Story.find(story_id) or raise "Error: Story not found"

      if story.update(status)
        say "#{status.titleize} ##{story_id}"
      else
        say "Error: Story did not update."
      end
    end

    %w(start finish deliver accept reject restart).each do |status|
      desc "#{status} STORY_ID", "#{status.titleize} a story on this project."
      define_method(status) do |story_id|
        edit(story_id, "#{status}ed")
      end
    end

    desc "create {bug|feature|chore} NAME", "Create a new story on this project"
    method_option :assign_to
    def create type, name
      with_attributes = options.merge(story_type: type, name: name)
      story = Story.create with_attributes

      if story.saved?
        say "Created #{type.titleize} ##{story.id}: '#{name}'"
      else
        say "Error saving #{type} with '#{name}'"
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
        # transformer = options[:stdout] ? make : plain_make
        if options[:stdout]
          id = plain_make(story.id, :YELLOW)
          author = plain_make(story.requested_by, :WHITE)
          status = if story.in_progress?
            plain_make(" (#{story.current_state})", :BLUE)
          else
            ""
          end
        else
          id = make(story.id, :YELLOW)
          author = make(story.requested_by, :cyan, true)
          status = if story.in_progress?
            make(" (#{story.current_state})", :BLUE)
          else
            ""
          end
        end

        # TODO: sort by status
        say [" #{id}", status, story.name, author].join(make( " | ", :red, true ))
      end

      def make(string, color, bold=false)
        set_color( string, Thor::Shell::Color.const_get(color.upcase.to_sym), bold)
      end

      def plain_make(string, color, bold=false)
        set_color( string, Thor::Shell::Color::WHITE, bold)
      end

      def full_render story
        s = story
        if options[:stdout]
          id = plain_make( "#{s.id}", :yellow )
          points = plain_make( "#{s.estimate} points", :red )
          author = plain_make(s.requested_by, :white)
          status = story.in_progress? ? plain_make(s.current_state,:green) : ""
          requester = plain_make(s.requested_by, :blue)
          owner = plain_make(s.owned_by, :white)
          type = plain_make(s.story_type.upcase, :red)
          name = plain_make(s.name, :red)
          description = plain_make(s.description, :white)
        else
          id = make( "#{s.id}", :yellow )
          points = make( "#{s.estimate} points", :red, true )
          author = make(s.requested_by, :white)
          status = story.in_progress? ? make(s.current_state,:green, true) : ""
          requester = make(s.requested_by, :blue)
          owner = make(s.owned_by, :white)
          type = make(s.story_type.upcase, :red)
          name = make(s.name, :red)
          description = make(s.description, :white)
        end

        temp = <<HERE
<%= "-"*60 %>
<%= type.titleize %>    <%= id %>   ( <%= points %> )
Status:       <%= status.rjust(25) %>
Requested By:  <%= requester.rjust(25) %>
Assigned To:  <%= owner.rjust(25) %>

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
