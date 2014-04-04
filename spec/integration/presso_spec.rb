require 'spec_helper'
require 'tmpdir'

describe Presso do
  GIT_PATH = File.expand_path('../../../.git', __FILE__)
  BINARY_FILE_PATH = File.join(GIT_PATH, 'index')
  ASCII_FILE_PATH = File.join(GIT_PATH, 'HEAD')

  let :dir_to_zip do
    'dir_to_zip'
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

  subject do
    described_class
  end

  it 'unzips all files in from directory that it zipped' do
    subject.zip_dir('my.zip', dir_to_zip)
    subject.unzip('my.zip', 'unzipped_dir')
    unzipped_files = Dir.chdir('unzipped_dir') { Dir['*'] }
    expect(unzipped_files).to include('index')
    expect(unzipped_files).to include('HEAD')
  end

  it 'unzips all files with correct bytesizes' do
    subject.zip_dir('my.zip', dir_to_zip)
    subject.unzip('my.zip', 'unzipped_dir')
    expect(File.size('unzipped_dir/index')).to eq File.size(BINARY_FILE_PATH)
    expect(File.size('unzipped_dir/HEAD')).to eq File.size(ASCII_FILE_PATH)
  end
end
