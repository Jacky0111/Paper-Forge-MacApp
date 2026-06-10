import Foundation

protocol JobStoring {
    func enqueue(_ job: DocumentJob)
    func update(_ job: DocumentJob)
    func allJobs() -> [DocumentJob]
}

final class InMemoryJobStore: JobStoring {
    private var jobs: [DocumentJob] = []

    func enqueue(_ job: DocumentJob) {
        jobs.append(job)
    }

    func update(_ job: DocumentJob) {
        guard let index = jobs.firstIndex(where: { $0.id == job.id }) else {
            jobs.append(job)
            return
        }

        jobs[index] = job
    }

    func allJobs() -> [DocumentJob] {
        jobs
    }
}
