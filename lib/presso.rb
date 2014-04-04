require 'java'

raise LoadError, "Incompatible JRuby version. Use at least JRuby 1.7.4. See JRUBY-7157." if JRUBY_VERSION =~ /^1\.7\.[0-3]$/

class Presso
  VERSION = '1.0.0'.freeze

  module JavaUtilZip
    include_package 'java.util.zip'
  end

  PressoError = Class.new(StandardError)

  def zip_dir(output_path, input_directory)
    raise PressoError, "Source directory #{input_directory} does not exist or is not a directory." unless File.directory?(input_directory)
    raise PressoError, "Target file #{output_path} already exists." if File.exists?(output_path)
    File.open(output_path, 'wb') do |file|
      stream = JavaUtilZip::ZipOutputStream.new(file.to_outputstream)
      Dir.chdir(input_directory) do
        Dir['**/*'].each do |path|
          if File.file?(path)
            stream.putNextEntry(JavaUtilZip::ZipEntry.new(path))
            IO.copy_stream(path, stream.to_io)
          elsif File.directory?(path)
            stream.putNextEntry(JavaUtilZip::ZipEntry.new(path+'/'))
          else
            raise PressoError, "File #{path} is not a regular file."
          end
        end
      end
      stream.close
    end
  end

  def unzip(input_path, output_directory)
    raise PressoError, "Source zip file #{input_path} does not exist or is not a file." unless File.file?(input_path)
    raise PressoError, "Target directory #{output_directory} already exists." if File.exists?(output_directory)
    File.open(input_path, 'rb') do |file|
      stream = JavaUtilZip::ZipInputStream.new(file.to_inputstream)
      FileUtils.mkdir_p(output_directory)
      Dir.chdir(output_directory) do
        while (entry = stream.next_entry)
          begin
            if entry.directory?
              FileUtils.mkdir_p(entry.name)
            else
              FileUtils.mkdir_p(File.dirname(entry.name))
              IO.copy_stream(stream.to_io, entry.name)
            end
          rescue Errno::EEXIST, Errno::EISDIR => e
            raise PressoError, "Filename conflict. #{entry.name} exists with different type.", e.backtrace
          end
          stream.close_entry
        end
      end
      stream.close
    end
  end
end
