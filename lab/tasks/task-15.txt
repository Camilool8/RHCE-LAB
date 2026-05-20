15. Configure cron jobs:

    Create /home/student/ansible/cron.yml playbook as per the following requirements:

    a) This playbook runs on all managed nodes in the hostgroup.
    b) Configure cronjob, which runs every 2 minutes and executes the following command: 'logger "EX294 exam in progress"' and run as user natasha.
