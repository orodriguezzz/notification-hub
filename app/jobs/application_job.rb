class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  # Registra el job en curso como origen de los envíos que haga
  around_perform do |job, block|
    Current.set(job: "#{job.class.name}##{job.job_id}") { block.call }
  end
end
