# Experiments

Create, read, update, and delete experiments. Manage tags, file uploads, analysis steps, and experiment-to-experiment links.

## CRUD

```@docs
create_experiment
create_from_template
get_experiment
update_experiment
delete_experiment
duplicate_experiment
list_experiments
search_experiments
```

## Tags

```@docs
tag_experiment
untag_experiment
list_tags
list_experiment_tags
clear_tags
clear_experiment_tags
```

## Uploads

```@docs
upload_to_experiment
list_experiment_uploads
update_experiment_upload
replace_experiment_upload
delete_experiment_upload
```

## Steps

```@docs
add_step
list_steps
finish_step
delete_step
update_step
notif_step
```

## Experiment Links

```@docs
link_experiments
list_experiment_links
unlink_experiments
```
