
# ROSA Commands to add nodes to cluster

[rosa@bastion ~]$ rosa list clusters
ID                                NAME        STATE  TOPOLOGY
2mdgsd85lpe26b1qg186non529e28arg  rosa-49b4z  ready  Hosted CP


```bash
rosa list machinepools --cluster rosa-zh8db
```

This command lists all machine pools for the specified ROSA (Red Hat OpenShift Service on AWS) cluster with ID `rosa-zh8db`.

Machine pools define the compute capacity and configuration for worker nodes in your ROSA cluster, including:
- Instance types
- Node counts
- Availability zones
- Autoscaling settings


rosa create machinepool --cluster=mycluster --interactive
