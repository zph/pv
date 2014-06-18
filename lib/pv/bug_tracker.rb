require 'pivotal-tracker'

module Pv
  class BugTracker
    attr_reader :username, :password, :token, :project

    # Connect to Pivotal Tracker
    def initialize with_username=nil, and_password=nil, and_project_id=nil
      raise "Configuration not found" unless Pv.config.present?

      @username = with_username || Pv.config.username
      @password = and_password  || Pv.config.password
      @token = PivotalTracker::Client.token(username, password)

      @projects = begin
        project_id = and_project_id || Pv.config.project_id
        PivotalTracker::Project.all.select { |p| project_id.include? p.id } if @token.present?
      end

      raise "Project ##{and_project_id} not found." if @projects.nil?

      PivotalTracker::Client.use_ssl = true
    end

    # Test whether we are connected.
    def connected?
      @token.present?
    end

    # Find stories filtered by this username.
    def stories by_user_name=nil
      user = by_user_name || Pv.config.name
      @projects.flat_map { |p| p.stories.all(owned_by: user).reject { |s| s.current_state =~ /accepted/ } }
    end

    # All stories
    def story_by_id(id)
      @projects.flat_map { |p| p.stories.find(id) }.compact.first
    end

    # All stories
    def stories_by_label(label)
      @projects.map { |p| p.stories.all(label: label) }
    end

  end
end
