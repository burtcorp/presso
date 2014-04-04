require 'java'

raise LoadError, "Incompatible JRuby version. Use at least JRuby 1.7.4. See JRUBY-7157." if JRUBY_VERSION =~ /^1\.7\.[0-3]$/

module Presso
  VERSION = '1.0.0'.freeze

  module JavaUtilZip
    include_package 'java.util.zip'
  end

  def self.zip_dir(zip, directory)
    File.open(zip, 'wb') do |file|
      stream = JavaUtilZip::ZipOutputStream.new(file.to_outputstream)
      Dir.chdir(directory) do
        Dir['**/*'].each do |path|
          if File.file?(path)
            stream.putNextEntry(JavaUtilZip::ZipEntry.new(path))
            IO.copy_stream(path, stream.to_io)
          elsif File.directory?(path)
            stream.putNextEntry(JavaUtilZip::ZipEntry.new(path+'/'))
          end
        end
      end
      stream.close
    end
  end

  def self.unzip(zip, directory)
    File.open(zip, 'rb') do |file|
      stream = JavaUtilZip::ZipInputStream.new(file.to_inputstream)
      Dir.mkdir(directory) unless File.directory?(directory)
      Dir.chdir(directory) do
        while (entry = stream.next_entry)
          if entry.directory?
            Dir.mkdir(entry.name)
          else
            IO.copy_stream(stream.to_io, entry.name)
          end
          stream.close_entry
        end
      end
      stream.close
    end
  end
end
