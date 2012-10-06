require 'spec_helper'

describe V0::MergesController do
  # it_should_behave_like "Secure API Controller"

  # helper for post :create with app_key automatically merged into arguments
  def post_create(args={})
    args.merge!({app_key: V0::ApplicationController::APP_KEY})
    post :create, args
  end

  # helper for get :show with app_key automatically merged into arguments
  def get_show(args={})
    args.merge!({app_key: V0::ApplicationController::APP_KEY})
    get :show, args
  end

  before do
    @acc = Account.make
  end

  describe "#create" do
    context "called with contact_ids of 2 owned contacts" do
      context "with conflicts" do
        before do
          account_1 = Account.make
          account_2 = Account.make
          account_3 = Account.make

          contact_attributes = {
              'father_telephone' => Telephone.make(:value => '111111111'),
              'father_email' => Email.make(:value => 'fathermail.com'),
              'son_telephone' => Telephone.make(:value => '555555555'),
              'son_email' => Email.make(:value => 'sonmail.com')
          }

          father_list = List.make
          son_list = List.make

          #Father
          father = Contact.make(:first_name => "Son", :last_name => "Goku", :level => "aspirante", :lists => [father_list], :owner => account_1)

          father.local_unique_attributes << LocalStatus.make(:value => :student, :account => account_1)
          father.local_unique_attributes << LocalStatus.make(:value => :prospect, :account => account_2)

          father.local_unique_attributes << LocalTeacher.make(:value => 'Roshi', :account => account_1)

          father.contact_attributes << [contact_attributes['father_telephone'], contact_attributes['father_email']]

          father.save

          #Son
          son = Contact.make(:first_name => "Son", :last_name => "Goku2", :level => "maestro", :lists => [son_list], :owner => account_1)

          son.local_unique_attributes << LocalStatus.make(:value => :former_student, :account => account_1)
          son.local_unique_attributes << LocalStatus.make(:value => :former_student, :account => account_2)
          son.local_unique_attributes << LocalStatus.make(:value => :former_student, :account => account_3)

          son.local_unique_attributes << LocalTeacher.make(:value => 'Kami', :account => account_1)
          son.local_unique_attributes << LocalTeacher.make(:value => 'Kaio', :account => account_2)

          son.contact_attributes << [contact_attributes['son_telephone'], contact_attributes['son_email']]

          son.save

          expect{
            post_create({account_name: account_1.name,
                        merge: {
                          first_contact_id: father.id.to_s,
                          second_contact_id: son.id.to_s
                        }})
          }.to change{Merge.count}
        end
        it "should create merge" do
          assert true # test is in before{...} this example if for indexation only
        end
        it { should respond_with 202 }
        it "should return merge's id" do
          JSON.parse(response.body).should == {'id' => Merge.last.id.to_s}
        end
        it "should leave merge with state :pending_confirmation" do
          state = Merge.find(JSON.parse(response.body)['id']).state
          state.should == 'pending_confirmation'
        end
      end
      context "without conflicts" do
        before do
          @a = Contact.make(owner: @acc, first_name: 'Bob', last_name: 'Marley')
          @b = Contact.make(owner: @acc, first_name: 'Bobby', last_name: 'Marley')

          @post_args = {account_name: @acc.name,
                        merge: {
                            first_contact_id: @a.id.to_s,
                            second_contact_id: @b.id.to_s
                        }
          }

          expect{
            post_create(@post_args)
          }.to change{Merge.count}
        end
        it "should create merge" do
          assert true # test is in before{...} this example if for indexation only
        end
        it { should respond_with 201 }
        it "should return merge's id" do
          JSON.parse(response.body).should == {'id' => Merge.last.id.to_s}
        end
        it "should start merge" do
          state = Merge.find(JSON.parse(response.body)['id']).state
          state.should_not be_in([:embryonic,:ready])
        end
      end
    end
    context "called with id of a contact not owned by account" do
      before do
        @a = Contact.make(owner: Account.make, first_name: 'Bob', last_name: 'Marley')
        @b = Contact.make(owner: @acc, first_name: 'Bobby', last_name: 'Marley')
        expect{
          post_create(account_name: @acc.name, merge: {
              first_contact_id: @a.id.to_s,
              second_contact_id: @b.id.to_s
          })
        }.not_to change{Merge.count}
      end
      it { should respond_with 401 }
      it "should not create merge" do
        assert true # spec here for indexation only. expectation on before.
      end
    end
    context "called with ids of unexisting contacts" do
      before do
        expect{
          post_create(account_name: @acc.name, merge: {
              first_contact_id: 'any-thing',
              second_contact_id: 'some-other-thing'
          })
        }.not_to change{Merge.count}
      end
      it { should respond_with 404 }
      it "should not create merge" do
        assert true # spec here for indexation only. expectation on before.
      end
    end
  end

  describe "#show" do
    context "called with valid id" do
      before do
        a = Contact.make(owner: @acc, first_name: 'Bob', last_name: 'Marley')
        b = Contact.make(owner: @acc, first_name: 'Bobby', last_name: 'Marley')
        @merge = Merge.new(first_contact_id: a.id, second_contact_id: b.id)
        @merge.save

        get_show id: @merge.id
      end
      it { should respond_with 200 }
      it "should return merge including it's state" do
        JSON.parse(response.body)['state'].should_not be_nil
      end
    end
  end

end