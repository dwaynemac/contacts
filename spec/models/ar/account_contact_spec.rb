# encoding: UTF-8
require 'ar_spec_helper'

describe AccountContact do
  
  it { should belong_to :contact }
  it { should belong_to :account }

  it { should validate_presence_of :account }
  it { should validate_presence_of :contact }

  it { should respond_to(:local_status, :coefficient, :observation, :local_teacher_username, :last_seen_at) }
end
