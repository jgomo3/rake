#!/usr/bin/env ruby

require 'test/unit'
require 'fileutils'
require 'rake'
require 'test/filecreation'

######################################################################
class TestFileTask < Test::Unit::TestCase
  include FileCreation

  def setup
    Task.clear
    @runs = Array.new
    FileUtils.rm_f NEWFILE
    FileUtils.rm_f OLDFILE
  end

  def test_file_need
    name = "testdata/dummy"
    file name
    ftask = Task[name]
    assert_equal name.to_s, ftask.name
    File.delete(ftask.name) rescue nil
    assert ftask.needed?, "file should be needed"
    open(ftask.name, "w") { |f| f.puts "HI" }
    assert_equal nil, ftask.prerequisites.collect{|n| Task[n].timestamp}.max
    assert ! ftask.needed?, "file should not be needed"
    File.delete(ftask.name) rescue nil
  end

  OLDFILE = "testdata/old"
  NEWFILE = "testdata/new"

  def test_file_times_new_depends_on_old
    create_timed_files(OLDFILE, NEWFILE)

    t1 = FileTask.lookup(NEWFILE).enhance([OLDFILE])
    t2 = FileTask.lookup(OLDFILE)
    assert ! t2.needed?, "Should not need to build old file"
    assert ! t1.needed?, "Should not need to rebuild new file because of old"
  end

  def test_file_times_old_depends_on_new
    create_timed_files(OLDFILE, NEWFILE)

    t1 = FileTask.lookup(OLDFILE).enhance([NEWFILE])
    t2 = FileTask.lookup(NEWFILE)
    assert ! t2.needed?, "Should not need to build new file"
    preq_stamp = t1.prerequisites.collect{|t| Task[t].timestamp}.max
    assert_equal t2.timestamp, preq_stamp
    assert t1.timestamp < preq_stamp, "T1 should be older"
    assert t1.needed?, "Should need to rebuild old file because of new"
  end

  def test_file_depends_on_task_depend_on_file
    create_timed_files(OLDFILE, NEWFILE)

    file NEWFILE => [:obj] do |t| @runs << t.name end
    task :obj => [OLDFILE] do |t| @runs << t.name end
    file OLDFILE           do |t| @runs << t.name end

    Task[:obj].invoke
    Task[NEWFILE].invoke
    assert ! @runs.include?(NEWFILE)
  end

  # I have currently disabled this test.  I'm not convinced that
  # deleting the file target on failure is always the proper thing to
  # do.  I'm willing to hear input on this topic.
  def ztest_file_deletes_on_failure
    task :obj 
    file NEWFILE => [:obj] do |t|
      FileUtils.touch NEWFILE
      fail "Ooops"
    end
    assert Task[NEWFILE]
    begin
      Task[NEWFILE].invoke
    rescue Exception
    end
    assert( ! File.exist?(NEWFILE), "NEWFILE should be deleted")
  end

end

######################################################################
class TestDirectoryTask < Test::Unit::TestCase
  def setup
    rm_rf "testdata", :verbose=>false
  end

  def teardown
    rm_rf "testdata", :verbose=>false
  end

  def test_directory
    desc "DESC"
    directory "testdata/a/b/c"
    assert_equal FileTask, Task["testdata"].class
    assert_equal FileTask, Task["testdata/a"].class
    assert_equal FileTask, Task["testdata/a/b/c"].class
    assert_nil             Task["testdata"].comment
    assert_equal "DESC",   Task["testdata/a/b/c"].comment
    assert_nil             Task["testdata/a/b"].comment
    verbose(false) {
      Task['testdata/a/b'].invoke
    }
    assert File.exist?("testdata/a/b")
    assert ! File.exist?("testdata/a/b/c")
  end

  def test_directory_win32
    desc "WIN32 DESC"
    FileUtils.mkdir_p("testdata")
    Dir.chdir("testdata") do
      directory 'c:/testdata/a/b/c'
      assert_equal FileTask, Task['c:/testdata'].class
      assert_equal FileTask, Task['c:/testdata/a'].class
      assert_equal FileTask, Task['c:/testdata/a/b/c'].class
      assert_nil             Task['c:/testdata'].comment
      assert_equal "WIN32 DESC",   Task['c:/testdata/a/b/c'].comment
      assert_nil             Task['c:/testdata/a/b'].comment
      verbose(false) {
	Task['c:/testdata/a/b'].invoke
      }
      assert File.exist?('c:/testdata/a/b')
      assert ! File.exist?('c:/testdata/a/b/c')
    end
  end
end
