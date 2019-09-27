# frozen_string_literal: true
require "abstract_unit"

class ForkTrackerTest < ActiveSupport::TestCase
  def test_object_fork
    read, write = IO.pipe
    handler = ActiveSupport::ForkTracker.after_fork { write.write "forked" }

    pid = fork do
      read.close
      write.close
      exit!
    end

    write.close

    Process.waitpid(pid)
    assert_equal "forked", read.read
    read.close
  ensure
    ActiveSupport::ForkTracker.unregister(handler)
  end

  def test_process_fork
    read, write = IO.pipe
    handler = ActiveSupport::ForkTracker.after_fork { write.write "forked" }

    pid = Process.fork do
      read.close
      write.close
      exit!
    end

    write.close

    Process.waitpid(pid)
    assert_equal "forked", read.read
    read.close
  ensure
    ActiveSupport::ForkTracker.unregister(handler)
  end

  def test_check
    count = 0
    handler = ActiveSupport::ForkTracker.after_fork { count += 1 }

    assert_no_difference -> { count } do
      3.times { ActiveSupport::ForkTracker.check! }
    end

    Process.stub(:pid, Process.pid + 1) do
      assert_difference -> { count }, +1 do
        3.times { ActiveSupport::ForkTracker.check! }
      end
    end

    assert_difference -> { count }, +1 do
      3.times { ActiveSupport::ForkTracker.check! }
    end
  ensure
    ActiveSupport::ForkTracker.unregister(handler)
  end
end
