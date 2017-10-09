# Totem Sample

This sample application demonstrates the file layout required required by Totem.  Totem can blue-green deploy this sample application because

* It contains the Totem Client.
* It has a *buildspec.yml* file.
* Its *buildspec.yml* file invokes Totem Client's *install.sh* and *commit_build.sh* scripts.
* It has the required *main.yaml*, *test-outgress.yaml*, *permanent-outgress.yaml*, and *permanent-ingress.yaml* AWS CloudFormation templates in *src/cfn*.
* It has the required system tests in *src/codebuild/main*.

## Quick start

See [Totem's Quick start instructions](https://github.com/Brightspace/totem).

## Documentation

See [Totem's documentation](https://github.com/Brightspace/totem).
