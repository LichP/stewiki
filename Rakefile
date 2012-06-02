require 'rake/gempackagetask'
require 'rake/testtask'

$:.unshift File.join(File.dirname(__FILE__), 'lib')
require 'stewiki'

namespace :test do
  require 'cutest'
  
  desc "Perform functional tests"
  task :functional do
    Cutest.run(Dir["./test/functional/*_test.rb"])
  end
  
  desc "Perform all tests"
  task :all => [:functional]
end

task :test => ["test:all"]

namespace :pry do
  require 'pry'
  
  task :default do
    binding.pry
  end
  
  namespace :scope do
  
    desc "PRY in scope of functional tests"
    task :test_functional do
      require 'cutest'
      require './test/helpers/functional'
      scope do
        binding.pry
      end
    end
  end
end

desc "Load the Stewiki library and drop to a PRY console"    
task :pry => ["pry:default"]
