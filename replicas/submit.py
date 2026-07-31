import flux
import flux.job
from flux.job import Jobspec
from flux.job.JobID import JobID

f = flux.Flux()
jobspec = Jobspec.from_yaml_file("/home/fluxuser/test.yaml")
jobid = flux.job.submit(f, jobspec)

t = flux.job.output.JobOutputWatchLines(f, jobid).getline()
print(t)