# encoding: utf-8
require 'spec_helper'

describe ContactSearcher do
  let(:searcher){ContactSearcher.new()}

  describe "#api_where" do

    def contact_w_age(age,estimated=false,estimated_on=nil)
      c = Contact.make
      if estimated
        c.estimated_age = age
        c.estimated_age_on = estimated_on if estimated_on
      else
        bdate = age.years.ago
        c.contact_attributes << DateAttribute.new(category: 'birthday',
                                                  year: bdate.year,
                                                  month: bdate.month,
                                                  day: bdate.day)
      end
      c.save
      c
    end

    context "{ younger_than: N }" do
      let!(:account){Account.make(name: 'acc-name', nucleo_id: 10)}
      let(:selector){{younger_than: 10}}
      it "returns contacts with age < 10" do
        c = contact_w_age 9
        expect(searcher.api_where(selector).first).to eq c
      end
      it "returns contacts with estimated_age < 10" do
        c = contact_w_age 9, true
        expect(searcher.api_where(selector).first).to eq c
      end
      it "wont return contacts wout age" do
        c = Contact.make
        expect(searcher.api_where(selector).first).not_to eq c
      end
      it "wont return contacts wi bdate wout year" do
        c = Contact.make
        bdate = 9.years.ago
        c.contact_attributes << DateAttribute.new(category: 'birthday',
                                                  month: bdate.month,
                                                  day: bdate.day)
        c.save
        expect(searcher.api_where(selector).first).not_to eq c
      end
      it "wont return contacts with age > 10" do
        c = contact_w_age 11
        expect(searcher.api_where(selector).first).not_to eq c
      end
      it "returns contacts with estimated_age > 10" do
        c = contact_w_age 11, true
        expect(searcher.api_where(selector).first).not_to eq c
      end
      it "considers estimated_age_on to calculate current estimated_age"
    end

    context "{ older_than: N }" do
      let(:selector){{older_than: 10}}
      it "returns contacts with age > 10" do
        c = contact_w_age 11
        expect(searcher.api_where(selector).first).to eq c
      end
      it "returns contacts with estimated_age > 10" do
        c = contact_w_age 11, true
        expect(searcher.api_where(selector).first).to eq c
      end
      it "wont return contacts wout age" do
        c = Contact.make
        expect(searcher.api_where(selector).first).not_to eq c
      end
      it "wont return contacts wi bdate wout year" do
        c = Contact.make
        bdate = 11.years.ago
        c.contact_attributes << DateAttribute.new(category: 'birthday',
                                                  month: bdate.month,
                                                  day: bdate.day)
        c.save
        expect(searcher.api_where(selector).first).not_to eq c
      end
      it "wont return contacts with age < 10" do
        c = contact_w_age 9
        expect(searcher.api_where(selector).first).not_to eq c
      end
      it "returns contacts with estimated_age < 10" do
        c = contact_w_age 9, true
        expect(searcher.api_where(selector).first).not_to eq c
      end
      it "considers estimated_age_on to calculate current estimated_age"
    end

    context "{ nucleo_unit_id: X }" do
      let!(:account){Account.make(name: 'acc-name', nucleo_id: 10)}
      let(:selector){{nucleo_unit_id: 10}}
      context "if account with nucleo_unit_id exists" do
        before do
          PadmaAccount.stub(:find_by_nucleo_id).and_return(PadmaAccount.new(name: 'acc-name'))
        end
        it "filter by account's contacts" do
          expect(searcher.api_where(selector)).to eq Contact.where(account_ids: account.id)
        end
      end
      context "if account with nucleo_unit_id does not exist" do
        before do
          Contact.make
          PadmaAccount.stub(:find_by_nucleo_id).and_return(nil)
        end
        it "returns empty array" do
          expect(searcher.api_where(selector).to_a).to be_empty
        end
      end
    end

    context "if all levels are selected" do
      context "including a blank" do
        let(:selector){{level: ['',
                               'aspirante',
                               'sádhaka',
                               'yôgin',
                               'chêla',
                               'graduado',
                               'asistente',
                               'docente',
                               'maestro']}}
        it "ignores level filter" do
          expect(searcher.api_where(selector).selector.keys).not_to include :level
        end
      end
      context "without a blank" do
        let(:selector){{level: ['aspirante',
                               'sádhaka',
                               'yôgin',
                               'chêla',
                               'graduado',
                               'asistente',
                               'docente',
                               'maestro']}}
        it "ignores level filter" do
          expect(searcher.api_where(selector).selector.keys).not_to include :level
        end
      end
    end
    context "if only some levels are selected" do
      let(:selector){{level: [
                             'sádhaka',
                             'yôgin',
                             'chêla',
                             'docente',
                             'maestro']}}
      it "filters by level" do
        expect(searcher.api_where(selector).selector.keys).to include :level
      end
    end
    context "{:email => 'dwa', :first_name => 'Ale'}" do
      let(:selector){{:email => "dwa", :first_name => "Ale"}}
      it "should be analog to .where(contact_attributes: { '$elemMatch' => { '_type' => 'Email', 'value' => /dwa/}}).where('first_name' => /Ale/)" do
        searcher.api_where(selector).selector.should == {
          'first_name' =>/Ale/i,
          :contact_attributes=>{"$elemMatch"=>{"_type"=>"Email", "value"=>/dwa/i}}
        }
      end
    end

    context "occupation: 'lawyear'" do
      let(:sel){{occupation: 'lawyer'}}
      it "returns contacts with lawyer occupation" do
        %W(judge lawyer).each do |occ|
          c = Contact.make
          c.contact_attributes << Occupation.new(value: occ)
          c.save
        end
        expect(searcher.api_where(sel).count).to eq 1
        expect(searcher.api_where(sel).first.occupations.first.value).to eq 'lawyer'
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
        searcher.api_where(sel).selector.should == { 'status' => :student}
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

    context "Custom attributes, account" do
      it "should return local_unique_attribute criteria" do
        account = Account.make
        c = Contact.make
        c.link(account)
        c.contact_attributes << CustomAttribute.new(value: 'as',
                                                    name: 'first-custom-key',
                                                    account: account)
        searcher.account_id = account.id
        searcher.api_where({'custom_first-custom-key' => 'as'}).selector.should == {
          contact_attributes: {
            '$elemMatch' => {_type: 'CustomAttribute', key: 'first-custom-key', value: /as/i, account_id: account.id}
          }
        }
      end
    end
    
    context " - coefficient - " do
      let!(:account){Account.make(name: 'belgrano')}
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
      context "{coefficient_for_belgrano: 'perfil'}" do
        it "should return local_unique_attribute criteria" do
          searcher.api_where({coefficient_for_belgrano: 'perfil'}).selector.should == {
            local_unique_attributes: {
              '$elemMatch' => {_type: 'Coefficient', value: {'$in' => ['perfil']}, account_id: account.id}
            }
          }
        end
      end

      context "{coefficient: ['','unknown','fp','pmenos','pmas','perfil'], account" do
        let(:query){{coefficient: ['','unknown','fp','pmenos','pmas','perfil']}}
        it "should ignore criteria" do
          searcher.account_id = account.id
          expect(searcher.api_where(query).selector).to eq( {} )
        end
      end

      context "{coefficient: ['unknown','fp','pmenos','pmas','perfil'], account" do
        let(:query){{coefficient: ['unknown','fp','pmenos','pmas','perfil']}}
        it "should ignore criteria" do
          searcher.account_id = account.id
          expect(searcher.api_where(query).selector).to eq({})
        end
      end

      context "{coefficient_for_belgrano: ['unknown','fp','pmenos','pmas','perfil']" do
        let(:query){{coefficient_for_belgrano: ['unknown','fp','pmenos','pmas','perfil']}}
        it "should ignore criteria" do
          expect(searcher.api_where(query).selector).to eq( {} )
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
        it "should return local_unique_attribute criteria inside $and if there are other criterias" do
          searcher.api_where({email: 'asdf', coefficient_for_belgrano: 'pmas'}).selector.should == {
            '$and' => [
              {contact_attributes: {'$elemMatch' => {'_type' => 'Email', 'value' => /asdf/i}}},
              {local_unique_attributes: {'$elemMatch' => {_type: 'Coefficient', value: {'$in' => ['pmas']}, account_id: account.id}}}
            ]
          }
        end

        it "should return local_unique_attribute criteria if there are no other criterias" do
          searcher.api_where({coefficient_for_belgrano: 'pmas'}).selector.should == {local_unique_attributes: {
              '$elemMatch' => {_type: 'Coefficient', value: {'$in' => ['pmas']}, account_id: account.id}
            }
          }
        end
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
