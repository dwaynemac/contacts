require 'spec_helper'

describe ContactSearcher do
  let(:searcher){ContactSearcher.new()}

  describe "#api_where" do
    context "{:email => 'dwa', :first_name => 'Ale'}" do
      let(:selector){{:email => "dwa", :first_name => "Ale"}}
      it "should be analog to .where(contact_attributes: { '$elemMatch' => { '_type' => 'Email', 'value' => /dwa/}}).where('first_name' => /Ale/)" do
        searcher.api_where(selector).selector.should == {
          :first_name =>/Ale/i,
          :contact_attributes=>{"$elemMatch"=>{"_type"=>"Email", "value"=>/dwa/i}}
        }
      end
    end
    
    context "email: 'dwa', telephone: '1234'" do
      let(:sel){{email: 'dwa', telephone: '1234'}}
      it "should build an $and" do
        searcher.api_where(sel).selector.should == {'$and' => [{:contact_attributes => {'$elemMatch' => {'_type' => 'Email','value' => /dwa/i}}},
                                                              {:contact_attributes => {'$elemMatch' => {'_type' => 'Telephone','value' => /1234/i}}}
                                                             ]}
      end
    end
    
    context "status: 'student'" do
      let(:sel){{status: 'student'}}
      it "should not set a regex" do
        searcher.api_where(sel).selector.should == {status: :student}
      end
    end
    
    context "{local_status: 'student'}, account" do
      it "should return local_unique_attribute criteria" do
        account = Account.make
        searcher.account_id = account.id
        searcher.api_where({local_status: 'student'}).selector.should == {
          local_unique_attributes: {
            '$elemMatch' => {_type: 'LocalStatus', value: {'$in' => ['student']}, account_id: account.id}
          }
        }
      end
    end
    
    context "{local_status: 'student', local_teacher: 'dwayne'}, account" do
      it "should return local_unique_attribute criteria" do
        account = Account.make
        searcher.account_id = account.id
        searcher.api_where({local_status: 'student', local_teacher: 'dwayne'}).selector.should == {
            '$and' => [
                {local_unique_attributes: {
                    '$elemMatch' => {_type: 'LocalStatus', value: {'$in' => ['student']}, account_id: account.id}
                }},
                {local_unique_attributes: {
                    '$elemMatch' => {_type: 'LocalTeacher', value: {'$in' => ['dwayne']}, account_id: account.id}
                }}
            ]
        }
      end
    end
    
    context "{coefficient: 'perfil'}, account" do
      it "should return local_unique_attribute criteria" do
        account = Account.make
        searcher.account_id = account.id
        searcher.api_where({coefficient: 'perfil'}).selector.should == {
          local_unique_attributes: {
            '$elemMatch' => {_type: 'Coefficient', value: {'$in' => ['perfil']}, account_id: account.id}
          }
        }
      end
    end

    context "{coefficient: ['perfil','pmas']}, account" do
      it "should return local_unique_attribute criteria" do
        account = Account.make
        searcher.account_id = account.id
        searcher.api_where({coefficient: ['perfil','pmas']}).selector.should == {
            local_unique_attributes: {
              '$elemMatch' => {_type: 'Coefficient',
                               value: {'$in' => ['perfil','pmas']},
                               account_id: account.id}
            }
        }
      end
    end

    context "{coefficient_for_belgrano: 'pmas'}" do
      before do
        @account = Account.make(name: 'belgrano')
      end

      it "should return local_unique_attribute criteria inside $and if there are other criterias" do
        searcher.api_where({email: 'asdf', coefficient_for_belgrano: 'pmas'}).selector.should == {
          '$and' => [
            {contact_attributes: {'$elemMatch' => {'_type' => 'Email', 'value' => /asdf/i}}},
            {local_unique_attributes: {'$elemMatch' => {_type: 'Coefficient', value: {'$in' => ['pmas']}, account_id: @account.id}}}
          ]
        }
      end

      it "should return local_unique_attribute criteria if there are no other criterias" do
        searcher.api_where({coefficient_for_belgrano: 'pmas'}).selector.should == {local_unique_attributes: {
            '$elemMatch' => {_type: 'Coefficient', value: {'$in' => ['pmas']}, account_id: @account.id}
          }
        }
      end
    end
  end
  
  describe "#get_account(private method)" do
    let(:belgrano){ Account.make(name: 'belgrano') }
    before do
      belgrano # create it
    end

    def get_account(ac_name)
      searcher.send(:get_account,ac_name)
    end

    describe "on first call" do
      it "fetches account from mongodb" do
        Account.should_receive(:where).with({name: 'belgrano'}).and_return([belgrano])
        get_account('belgrano')
      end
    end
    describe "on second call" do
      before { get_account('belgrano') }
      it "reads from cache" do
        get_account('belgrano').should == belgrano
      end
      it "doesnt call mongodb" do
        Account.should_not_receive(:where)
        get_account('belgrano')
      end
    end
  end
end
