desc 'format'
task :format do
  sh 'find . -name "*.d" | xargs dfmt -i'
end
