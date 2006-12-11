require 'English'
require File.dirname(__FILE__) + '/dialog'

module TextMate

  # Call the given block while showing a progress dialog. By default, the progress bar is
  # indeterminate/indefinite/'barber pole.'
  #
  # Note that the cancel button is only available when you provide the :cancel argument, which is
  # expected to be a proc. To support the cancel button, the primary block is forked into a new
  # process. When the cancel button is pressed, the cancel proc is also executed in the new process.
  # At that point, you can Kernel.exit the process directly from the cancel block (as in the code
  # above) or set a global variable for orderly shutdown.
  #
  # TODO: this may need additional work to make cancel detectable from the client script.
  def TextMate.call_with_progress( args, &block )
    title           = args[:title] || 'Progress'
    message         = args[:message] || args[:summary] || 'Frobbing the widget...'
    cancel_proc     = args[:cancel]
    indeterminate   = args[:indeterminate]
    indeterminate   = true if indeterminate.nil?
        
    params = {'title' => title,
              'summary' => message,
              'details' => '',
              'isIndeterminate' => indeterminate}

    params['cancelButtonHidden'] = false unless cancel_proc.nil?
    
    run_block = Proc.new do |dialog|
      if block.arity == 0
        block.call
      else
        block.call(dialog)
      end
    end
    
    Dialog.dialog('ProgressDialog.nib', params) do |dialog|
      if cancel_proc.nil?
        # if there is no cancel proc, we get no input from the dialog and need not block.
        run_block.call(dialog)
      else # not cancel_proc.nil?
        
        # invoke processing block in one process
        run_block_process = fork do
            trap('SIGINT'){cancel_proc.call}
            run_block.call(dialog)
        end

        # invoke ui waiting in a second process
        ui_process = fork do
          begin
            dialog.wait_for_input do |params|
              # tell the main process to run the cancel_proc
              Process.kill('SIGINT', run_block_process) if params['returnButton'] == 'Cancel' # FIXME localization problem...
              false
            end
          rescue TextMate::WindowNotFound
              # ignore; the window was probably canceled
          end
        end
        
        # hang out until the dialog is done
        Process.wait
      end
    end
  end
  
end

# test
if __FILE__ == $0

  # indeterminate
  TextMate.call_with_progress(:title =>'Now Testing',
          :summary => 'Starting Up...') do

    sleep 3
  end

  # finite
  TextMate.call_with_progress(:title =>'Now Testing',
          :summary => 'Starting Up...',
          :indeterminate => false,
          :cancel => lambda {puts "Canceled!"; exit 0} ) do |dialog|

    sleep 1
    dialog.parameters = {'summary' => 'Loving the alien...','progressValue' => 30 }
    sleep 1
    dialog.parameters = {'summary' => 'Eating the pie...','progressValue' => 60 }
    sleep 1
    dialog.parameters = {'summary' => 'Vacuuming the rug...','progressValue' => 90 }
    sleep 1
    dialog.parameters = {'summary' => 'Complete!','progressValue' => 100 }
    sleep 2
  end
end
