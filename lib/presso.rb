require 'java'

raise LoadError, "Incompatible JRuby version. Use at least JRuby 1.7.4. See JRUBY-7157." if JRUBY_VERSION =~ /^1\.7\.[0-3]$/

class Presso
  VERSION = '1.0.0'.freeze

  module JavaUtilZip
    include_package 'java.util.zip'
  end

  PressoError = Class.new(StandardError)

  def zip_dir(output_path, input_directory)
    output_path = File.expand_path(output_path)
    Dir.chdir(input_directory) do
      File.open(output_path, File::WRONLY|File::CREAT|File::EXCL, binmode: true) do |file|
        stream = JavaUtilZip::ZipOutputStream.new(file.to_outputstream)
        stream_io = stream.to_io
        Dir['**/*'].each do |path|
          if File.file?(path)
            stream.put_next_entry(JavaUtilZip::ZipEntry.new(path))
            IO.copy_stream(path, stream_io)
            stream_io.flush
          elsif File.directory?(path)
            stream.put_next_entry(JavaUtilZip::ZipEntry.new(path+'/'))
          else
            raise PressoError, "File #{path} is not a regular file."
          end
        end
        stream_io.close
      end
    end
  end

  def unzip(input_path, output_directory)
    raise PressoError, "Target directory #{output_directory} already exists." if File.exists?(output_directory)
    File.open(input_path, 'rb') do |file|
      stream = JavaUtilZip::ZipInputStream.new(file.to_inputstream)
      stream_io = stream.to_io
      FileUtils.mkdir_p(output_directory)
      Dir.chdir(output_directory) do
        while (entry = stream.next_entry)
          if entry.directory?
            FileUtils.mkdir_p(entry.name)
          else
            FileUtils.mkdir_p(File.dirname(entry.name))
            IO.copy_stream(stream_io, entry.name)
          end
          stream.close_entry
        end
      end
      stream_io.close
    end
  end
end
