require 'spec_helper'
require 'zipkin-tracer/hostname_resolver'

describe ZipkinTracer::HostnameResolver do
  let(:span_id) { 'c3a555b04cf7e099' }
  let(:parent_id) { 'f0e71086411b1445' }
  let(:sampled) { true }
  let(:trace_id) { Trace::TraceId.new(span_id, nil, span_id, sampled, Trace::Flags::EMPTY) }
  let(:name) { 'raist' }
  let(:ipv4) { '100.100.100.100' }
  let(:hostname) { 'www.trusmis.com' }
  let(:endpoint) { Trace::Endpoint.new(hostname, 80, name) }
  let(:local_hostname) { 'MRBADGUY' }
  let(:local_endpoint) { Trace::Endpoint.new(local_hostname, 80, name) }
  let(:span) { Trace::Span.new(name, trace_id) }
  let(:resolved_spans) { described_class.new.spans_with_ips([span]) }

  context 'no spans' do
    it 'returns an empty array' do
      expect(described_class.new.spans_with_ips([])).to eq([])
    end
  end


  shared_examples_for 'resolves hostnames' do
    it 'returns an array of spans' do
      expect(resolved_spans).to be_kind_of(Array)
    end

    it 'The returned array contains spans' do
      expect(resolved_spans.first).to be_kind_of(Trace::Span)
    end

    it 'resolves the hostnames in the annotations' do
      ip = resolved_spans.first.annotations.first.host.ipv4
      expect(ip).to eq(expected_ip)
    end

    it 'resolves the hostnames in the binnary annotations' do
      ip = resolved_spans.first.binary_annotations.first.host.ipv4
      expect(ip).to eq(expected_ip)
    end

    context 'host lookup failure' do
      before { allow(Socket).to receive(:getaddrinfo).and_raise }
      context 'i32' do
       before { current_endpoint.ip_format = :i32 }
        it 'falls back to localhost as an i32' do
          ip = resolved_spans.first.annotations.first.host.ipv4
          expect(ip).to eq(0x7f000001)
        end
      end

      context 'string' do
        before { current_endpoint.ip_format = :string }
        it 'falls back to localhost as an string' do
          ip = resolved_spans.first.annotations.first.host.ipv4
          expect(ip).to eq('127.0.0.1')
        end
      end
    end
  end

  context 'resolving to i32 addresses' do
    before do
      endpoint.ip_format = :i32
      Trace.default_endpoint = endpoint
      span.record('diary')
      span.record_tag('secret', 'book')
      allow(Socket).to receive(:getaddrinfo).with(hostname, nil).and_return([[nil, nil, nil, ipv4]])
    end
    let(:expected_ip) { 1684300900 }  # 1684300900 == 100.100.100.100 into i32 notation
    let(:current_endpoint) { endpoint }

    it_should_behave_like 'resolves hostnames'
  end


  context 'with spans containing local addresses' do
    before do
      local_endpoint.ip_format = :string
      Trace.default_endpoint = local_endpoint
      span.record('diary')
      span.record_tag('secret', 'book')
      allow(Socket).to receive(:getaddrinfo).with(local_hostname, nil, :INET).and_return([[nil, nil, nil, ipv4]])
    end
    let(:expected_ip) { ipv4 }
    let(:current_endpoint) { local_endpoint }
    it_should_behave_like 'resolves hostnames'
  end


  context 'with spans resolving to string addresses' do
    before do
      endpoint.ip_format = :string
      Trace.default_endpoint = endpoint
      span.record('diary')
      span.record_tag('secret', 'book')
      allow(Socket).to receive(:getaddrinfo).with(hostname, nil, :INET).and_return([[nil, nil, nil, ipv4]])
    end
    let(:expected_ip) { ipv4 }
    let(:current_endpoint) { endpoint }
    it_should_behave_like 'resolves hostnames'
  end

end
