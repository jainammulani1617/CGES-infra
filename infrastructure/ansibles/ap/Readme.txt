To unmount mounted point:
--------------------------------------
df -h
sudo umount <mount-point>


To install AP (7.0.0) PRODUCTION, use following command:
--------------------------------------
ansible-playbook -i /home/public.monitor/infrastructure/ansibles/ap/inventory.ini /home/public.monitor/infrastructure/ansibles/ap/install_ap.yaml -e "target_hosts=cap_prod_servers" -e "jdk_version=21" -e "oxalis_version=7.0.0" -e "tomcat_major_version=10" -e "tomcat_sub_version=10.1.30" -e "manager_password=Secure1234" -e "admin_password=Secure1234" -e "nfs_server=172.25.4.233" -e "nfs_folder=prod_nfs" -e "nfs_server_secondary=" -e "nfs_folder_secondary=" -e "nfs_user=public.monitor" -e "nfs_user_domain=cygdc.local" -e "ap_certificate_name=peppol-ap.jks" -e "ap_certificate_password=MLkHBGVTaTiU" -e "ap_serverdomain=ap.cygnet.one" --ask-pass --ask-become-pass


To install AP (7.0.0) STAGING, use following command:
--------------------------------------
ansible-playbook -i /home/public.monitor/infrastructure/ansibles/ap/inventory.ini /home/public.monitor/infrastructure/ansibles/ap/install_ap.yaml -e "target_hosts=cap_stag_servers" -e "jdk_version=21" -e "oxalis_version=7.0.0" -e "tomcat_major_version=10" -e "tomcat_sub_version=10.1.30" -e "manager_password=Secure1234" -e "admin_password=Secure1234" -e "nfs_server=172.25.4.103" -e "nfs_folder=stag_nfs" -e "nfs_server_secondary=" -e "nfs_folder_secondary=" -e "nfs_user=public.monitor" -e "nfs_user_domain=cygdc.local" -e "ap_certificate_name=sandbox-peppol-ap.jks" -e "ap_certificate_password=Z8nzkj9kNf6r" -e "ap_serverdomain=staging-ap.cygnet.one" --ask-pass --ask-become-pass


To install AP (7.0.0) QA, use following command:
--------------------------------------
ansible-playbook -i /home/cprod.developer/infrastructure/cges/ap/inventory.ini /home/cprod.developer/infrastructure/cges/ap/install_ap.yaml -e "target_hosts=cap_dev_servers" -e "jdk_version=21" -e "oxalis_version=7.0.0" -e "tomcat_major_version=10" -e "tomcat_sub_version=10.1.30" -e "manager_password=Secure1234" -e "admin_password=Secure1234" -e "nfs_server=172.19.14.54" -e "nfs_folder=qa_nfs" -e "nfs_server_secondary=172.19.14.2" -e "nfs_folder_secondary=cygnetap/fedev_nfs" -e "nfs_user=public.monitor" -e "nfs_user_domain=cygdc.local" -e "ap_certificate_name=sandbox-peppol-ap.jks" -e "ap_certificate_password=Z8nzkj9kNf6r" -e "ap_serverdomain=dev-ap.cygnet.one" --ask-pass --ask-become-pass