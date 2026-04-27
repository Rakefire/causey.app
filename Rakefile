require "bridgetown"

Bridgetown.load_tasks

task default: :deploy

desc "Build the Bridgetown site for deployment"
task :deploy => [:clean] do
  Bridgetown::Commands::Build.start
end

desc "Build the site in a test environment"
task :test do
  ENV["BRIDGETOWN_ENV"] = "test"
  Bridgetown::Commands::Build.start
end

desc "Runs the clean command"
task :clean do
  Bridgetown::Commands::Clean.start
end
