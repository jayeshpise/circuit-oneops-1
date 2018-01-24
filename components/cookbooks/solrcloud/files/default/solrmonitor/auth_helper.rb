
module Solr
  module AuthHelper

    $secrete_dir = "/app/solr_secrets"
    $secrete_file_name = "solr_secrete_file"

    def auth_enabled?
      return File.file?("#{$secrete_dir}/#{$secrete_file_name}")
    end

    def get_solr_admin_credentials()
      file = File.read("#{$secrete_dir}/#{$secrete_file_name}")
      secrete_file = JSON.parse(file)
      return secrete_file['admin_user']
    end

    def get_solr_user_credentials(user)
      file = File.read("#{$secrete_dir}/#{$secrete_file_name}")
      secrete_file = JSON.parse(file)
      return secrete_file[user]
    end
  end
end


