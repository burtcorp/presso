require 'spec_helper'
require 'tmpdir'
require 'socket'

describe Presso do
  GIT_PATH = File.expand_path('../../../.git', __FILE__)
  BINARY_FILE_PATH = File.join(GIT_PATH, 'index')
  ASCII_FILE_PATH = File.join(GIT_PATH, 'HEAD')

  let :dir_to_zip do
    File.expand_path('dir_to_zip')
  end

  around do |example|
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        FileUtils.mkdir dir_to_zip
        FileUtils.cp [BINARY_FILE_PATH, ASCII_FILE_PATH], dir_to_zip
        example.call
      end
    end
  end

  it 'zips and unzips all files in target directory' do
    subject.zip_dir('my.zip', dir_to_zip)
    subject.unzip('my.zip', 'unzipped_dir')
    unzipped_files = Dir.chdir('unzipped_dir') { Dir['*'] }
    expect(unzipped_files).to include('index')
    expect(unzipped_files).to include('HEAD')
  end

  it 'zips and unzips all files with correct bytesizes' do
    subject.zip_dir('my.zip', dir_to_zip)
    subject.unzip('my.zip', 'unzipped_dir')
    expect(File.size('unzipped_dir/index')).to eq File.size(BINARY_FILE_PATH)
    expect(File.size('unzipped_dir/HEAD')).to eq File.size(ASCII_FILE_PATH)
  end

  it 'zips and unzips files insides subdirectories' do
    subdirectory = 'sub/directories'
    FileUtils.mkdir_p File.join(dir_to_zip, subdirectory)
    FileUtils.mv File.join(dir_to_zip, 'index'), File.join(dir_to_zip, subdirectory)
    subject.zip_dir('my.zip', dir_to_zip)
    subject.unzip('my.zip', 'unzipped_dir')
    expect(File.size('unzipped_dir/sub/directories/index')).to eq File.size(BINARY_FILE_PATH)
  end

  describe '#zip_dir' do
    it 'raises an error unless the target directory exists' do
      expect { subject.zip_dir('foo.zip', 'non-existent-dir') }.to raise_error(Errno::ENOENT, /non-existent-dir/)
    end

    it 'raises an error if the target zip archive already exists' do
      FileUtils.touch 'foo.zip'
      expect { subject.zip_dir('foo.zip', dir_to_zip) }.to raise_error(Errno::EEXIST, /foo\.zip/)
    end

    it 'resolves absolute symbolic links and adds the target file' do
      FileUtils.ln_s File.join(dir_to_zip, 'HEAD'), File.join(dir_to_zip, 'link')
      subject.zip_dir('my.zip', dir_to_zip)
      subject.unzip('my.zip', 'unzipped_dir') # TODO: use jar xf
      expect(File.symlink?('unzipped_dir/link')).to be_false
      expect(File.size('unzipped_dir/link')).to eq File.size(ASCII_FILE_PATH)
    end

    it 'resolves relative symbolic links and adds the target file' do
      FileUtils.ln_s 'HEAD', File.join(dir_to_zip, 'link')
      subject.zip_dir('my.zip', dir_to_zip)
      subject.unzip('my.zip', 'unzipped_dir') # TODO: use jar xf
      expect(File.symlink?('unzipped_dir/link')).to be_false
      expect(File.size('unzipped_dir/link')).to eq File.size(ASCII_FILE_PATH)
    end

    it 'raises an error when encountering an entry that is not a file' do
      UNIXServer.open(File.join(dir_to_zip, 'not_a_file')) do
        expect { subject.zip_dir('my.zip', dir_to_zip) }.to raise_error(Presso::PressoError, /not_a_file.*not a regular file/)
      end
    end
  end

  describe '#unzip' do
    def create_zip_with_duplicate_entries(filename)
      FileUtils.cp File.join(dir_to_zip, 'index'), File.join(dir_to_zip, 'HEAE')
      `jar cMf #{filename} -C #{dir_to_zip} HEAD -C #{dir_to_zip} HEAE`
      File.binwrite filename, File.binread(filename).gsub('HEAE', 'HEAD')
    end

    it 'raises an error if the source archive does not exist' do
      expect { subject.unzip('non-existent.zip', 'somewhere') }.to raise_error(Errno::ENOENT, /non-existent\.zip/)
    end

    it 'raises an error if the target directory already exists' do
      FileUtils.mkdir 'existent-dir'
      FileUtils.touch 'my.zip'
      expect { subject.unzip('my.zip', 'existent-dir') }.to raise_error(Presso::PressoError, /existent-dir.*already exists/)
    end

    it 'unpacks a file' do
      `jar cMf my.zip -C #{dir_to_zip} HEAD`
      subject.unzip('my.zip', 'unzipped_dir')
      expect(File.size(File.join('unzipped_dir', 'HEAD'))).to eq File.size(ASCII_FILE_PATH)
    end

    it 'unpacks to a nested directory structure that does not exist' do
      `jar cMf my.zip -C #{dir_to_zip} HEAD`
      subject.unzip('my.zip', 'some/unzipped/dir')
      expect(File.size('some/unzipped/dir/HEAD')).to eq File.size(ASCII_FILE_PATH)
    end

    it 'unpacks a directory' do
      FileUtils.mkdir 'empty-directory'
      `jar cMf my.zip empty-directory`
      subject.unzip('my.zip', 'unzipped_dir')
      expect(File.directory?(File.join('unzipped_dir', 'empty-directory'))).to be_true
    end

    it 'automatically creates parent directories' do
      `jar cMf my.zip dir_to_zip/HEAD`
      subject.unzip('my.zip', 'unzipped_dir')
      expect(File.directory?(File.join('unzipped_dir', 'dir_to_zip'))).to be_true
      expect(File.size(File.join('unzipped_dir', 'dir_to_zip', 'HEAD'))).to eq File.size(ASCII_FILE_PATH)
    end

    it 'uses the last of duplicate entries' do
      create_zip_with_duplicate_entries 'my.zip'
      subject.unzip('my.zip', 'unzipped_dir')
      expect(File.size(File.join('unzipped_dir', 'HEAD'))).to eq File.size(BINARY_FILE_PATH)
    end

    it 'raises an error when there is a file entry followed by a directory entry with the same name' do
      FileUtils.mkdir 'HEAD'
      `jar cMf my.zip -C #{dir_to_zip} HEAD HEAD`
      expect { subject.unzip('my.zip', 'unzipped_dir') }.to raise_error(Errno::EEXIST, /HEAD/)
    end

    it 'raises an error when there is a directory entry followed by a file entry with the same name' do
      FileUtils.mkdir 'HEAD'
      `jar cMf my.zip HEAD -C #{dir_to_zip} HEAD`
      expect { subject.unzip('my.zip', 'unzipped_dir') }.to raise_error(Errno::EISDIR)
    end
  end
end
