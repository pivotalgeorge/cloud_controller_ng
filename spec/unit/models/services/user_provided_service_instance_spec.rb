require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::UserProvidedServiceInstance, type: :model do
    let(:service_instance) { VCAP::CloudController::UserProvidedServiceInstance.make }

    it_behaves_like "a model with an encrypted attribute" do
      def new_model
        described_class.create(
          :name => Sham.name,
          :space => VCAP::CloudController::Space.make,
          :credentials => value_to_encrypt,
        )
      end

      let(:encrypted_attr) { :credentials }
    end

    it_behaves_like "a CloudController model", {
      many_to_one: {
        space: {
          delete_ok: true,
          create_for: proc { VCAP::CloudController::Space.make },
        },
      },
    }

    describe "Validations" do
      it { should validate_presence :name }
      it { should validate_presence :space }
      it { should strip_whitespace :name }
      it { should strip_whitespace :syslog_drain_url }

      it "should not bind an app and a service instance from different app spaces" do
        service_instance = described_class.make
        VCAP::CloudController::AppFactory.make(:space => service_instance.space)
        service_binding = VCAP::CloudController::ServiceBinding.make
        expect {
          service_instance.add_service_binding(service_binding)
        }.to raise_error VCAP::CloudController::ServiceInstance::InvalidServiceBinding
      end
    end

    describe "#create" do
      it "saves with is_gateway_service false" do
        instance = described_class.create(
          name: 'awesome-service',
          space: VCAP::CloudController::Space.make,
          credentials: {"foo" => "bar"},
        )
        instance.refresh.is_gateway_service.should be_false
      end

      it 'creates a CREATED service usage event' do
        instance = described_class.make

        event = ServiceUsageEvent.last
        expect(ServiceUsageEvent.count).to eq(1)
        expect(event.state).to eq(Repositories::Services::ServiceUsageEventRepository::CREATED_EVENT_STATE)
        expect(event).to match_service_instance(instance)
      end
    end

    describe '#delete' do
      it 'creates a DELETED service usage event' do
        instance = described_class.make
        instance.destroy

        event = VCAP::CloudController::ServiceUsageEvent.last

        expect(VCAP::CloudController::ServiceUsageEvent.count).to eq(2)
        expect(event.state).to eq(Repositories::Services::ServiceUsageEventRepository::DELETED_EVENT_STATE)
        expect(event).to match_service_instance(instance)
      end
    end

    describe "serialization" do
      it "includes its type" do
        expect(Yajl::Parser.parse(service_instance.to_json).fetch("type")).to eq "user_provided_service_instance"
      end
    end

    describe "#tags" do
      it 'does not have tags' do
        service_instance = described_class.make
        expect(service_instance.tags).to eq []
      end
    end
  end
end
