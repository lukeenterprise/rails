# frozen_string_literal: true

module ActiveSupport
  module ForkTracker # :nodoc:
    module CoreExt
      def fork(*)
        super do
          ForkTracker.after_fork!
          yield
        end
      end
    end

    @pid = Process.pid
    @callbacks = []

    class << self
      def check!
        after_fork! if @pid != Process.pid
      end

      def hook!
        ::Object.prepend(CoreExt)
        ::Process.singleton_class.prepend(CoreExt)
      end

      def after_fork(&block)
        @callbacks << block
        block
      end

      def unregister(callback)
        @callbacks.delete(callback)
      end

      def after_fork!
        @pid = Process.pid
        @callbacks.each(&:call)
        nil
      end
    end
  end
end

ActiveSupport::ForkTracker.hook!
