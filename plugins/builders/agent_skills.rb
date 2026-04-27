require "digest"
require "fileutils"
require "json"

class Builders::AgentSkills < SiteBuilder
  SCHEMA_URL = "https://schemas.agentskills.io/discovery/0.2.0/schema.json".freeze
  SOURCE_DIR = "agent_skills".freeze
  DEST_DIR = ".well-known/agent-skills".freeze

  def build
    hook :site, :post_write do
      generate
    end
  end

  private

  def generate
    skills_data = site.data.dig("agent_skills", "skills") || []
    return if skills_data.empty?

    repo_root = File.expand_path("..", site.source)
    dest_root = File.join(site.config["destination"], DEST_DIR)
    FileUtils.mkdir_p(dest_root)

    skills = skills_data.map do |s|
      name = s["name"]
      src_path = File.join(repo_root, SOURCE_DIR, name, "SKILL.md")

      unless File.exist?(src_path)
        Bridgetown.logger.warn "AgentSkills:", "missing #{src_path}"
        next nil
      end

      bytes = File.binread(src_path)
      dest_path = File.join(dest_root, name, "SKILL.md")
      FileUtils.mkdir_p(File.dirname(dest_path))
      File.binwrite(dest_path, bytes)

      {
        "name" => name,
        "type" => s["type"] || "skill-md",
        "description" => s["description"],
        "url" => "/#{DEST_DIR}/#{name}/SKILL.md",
        "digest" => "sha256:#{Digest::SHA256.hexdigest(bytes)}"
      }
    end.compact

    index = {
      "$schema" => SCHEMA_URL,
      "skills" => skills
    }

    File.write(File.join(dest_root, "index.json"), JSON.pretty_generate(index) + "\n")

    Bridgetown.logger.info "AgentSkills:", "wrote #{skills.size} skill(s) + index.json"
  end
end
