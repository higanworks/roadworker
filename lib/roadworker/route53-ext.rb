require 'aws-sdk'

module Aws
  module Route53

    # http://docs.aws.amazon.com/general/latest/gr/rande.html#s3_region
    S3_WEBSITE_ENDPOINTS = {
      's3-website-us-east-1.amazonaws.com'      => 'z3AQBSTGFYJSTF',
      's3-website-us-west-2.amazonaws.com'      => 'z3BJ6K6RIION7M',
      's3-website-us-west-1.amazonaws.com'      => 'z2F56UZL2M1ACD',
      's3-website-eu-west-1.amazonaws.com'      => 'z1BKCTXD74EZPE',
      's3-website.eu-central-1.amazonaws.com'   => 'z21DNDUVLTQW6Q',
      's3-website-ap-southeast-1.amazonaws.com' => 'z3O0J2DXBE1FTB',
      's3-website-ap-southeast-2.amazonaws.com' => 'z1WCIGYICN2BYD',
      's3-website-ap-northeast-1.amazonaws.com' => 'z2M4EHUR26P7ZW',
      's3-website-sa-east-1.amazonaws.com'      => 'z7KQH4QJS55SO',
      's3-website-us-gov-west-1.amazonaws.com'  => 'z31GFT0UA1I2HV',
    }

    # http://docs.aws.amazon.com/Route53/latest/APIReference/API_ChangeResourceRecordSets.html
    CF_HOSTED_zONE_ID = 'Z2FDTNDATAQYW2'

    class << self
      def normalize_dns_name_options(src)
        dst = {}

        {
          :evaluate_target_health => false,
        }.each do |key, defalut_value|
          dst[key] = src[key] || false
        end

        return dst
      end

      def dns_name_to_alias_target(name, options, hosted_zone_id, hosted_zone_name)
        hosted_zone_name = hosted_zone_name.sub(/\.\z/, '')
        name = name.sub(/\.\z/, '')
        options ||= {}

        if name =~ /([^.]+)\.elb\.amazonaws.com\z/i
          region = $1.downcase
          alias_target = elb_dns_name_to_alias_target(name, region, options)

          # XXX:
          alias_target.merge(options)
        elsif (s3_hosted_zone_id = S3_WEBSITE_ENDPOINTS[name.downcase]) and name =~ /\As3-website-([^.]+)\.amazonaws\.com\z/i
          region = $1.downcase
          s3_dns_name_to_alias_target(name, region, s3_hosted_zone_id)
        elsif name =~ /\.cloudfront\.net\z/i
          cf_dns_name_to_alias_target(name)
        elsif name =~ /(\A|\.)#{Regexp.escape(hosted_zone_name)}\z/i
          this_hz_dns_name_to_alias_target(name, hosted_zone_id)
        else
          raise "Invalid DNS Name: #{name}"
        end
      end

      private

      def elb_dns_name_to_alias_target(name, region, options)
        if options[:hosted_zone_id]
          {
            :hosted_zone_id => options[:hosted_zone_id],
            :dns_name       => name,
            :evaluate_target_health => false, # XXX:
          }
        else
          elb = Aws::ElasticLoadBalancing::Client.new(:region => region)

          load_balancer = nil
          elb.describe_load_balancers.each do |page|
            page.load_balancer_descriptions.each do |lb|
              if lb.dns_name == name
                load_balancer = lb
              end
            end
            break if load_balancer
          end

          unless load_balancer
            raise "Cannot find ELB: #{name}"
          end

          {
            :hosted_zone_id         => load_balancer.canonical_hosted_zone_name_id,
            :dns_name               => load_balancer.dns_name,
            :evaluate_target_health => false, # XXX:
          }
        end
      end

      def s3_dns_name_to_alias_target(name, region, hosted_zone_id)
        {
          :hosted_zone_id         => hosted_zone_id,
          :dns_name               => name,
          :evaluate_target_health => false, # XXX:
        }
      end

      def cf_dns_name_to_alias_target(name)
        {
          :hosted_zone_id         => CF_HOSTED_zONE_ID,
          :dns_name               => name,
          :evaluate_target_health => false, # XXX:
        }
      end

      def this_hz_dns_name_to_alias_target(name, hosted_zone_id)
        {
          :hosted_zone_id         => hosted_zone_id,
          :dns_name               => name,
          :evaluate_target_health => false, # XXX:
        }
      end
    end # of class method

  end # Route53
end # Roadworker
