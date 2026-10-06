import Foundation

struct Project: Identifiable, Hashable {
    let workspace: Workspace
    let repository: GitRepository?

    var id: URL { workspace.url }
    var name: String { workspace.name }
    var group: String { workspace.group }
    var root: URL { workspace.root }
    var url: URL { workspace.url }
    var searchText: String { workspace.searchText }

    static func merge(workspaces: [Workspace], repositories: [GitRepository]) -> [Project] {
        var unclaimedRepositories = Dictionary(uniqueKeysWithValues: repositories.map { ($0.url.standardizedFileURL.path, $0) })

        let workspaceProjects = workspaces.map { workspace in
            let claimedRepositories = workspace.directories.compactMap {
                unclaimedRepositories.removeValue(forKey: $0.standardizedFileURL.path)
            }
            return Project(workspace: workspace, repository: claimedRepositories.first)
        }

        let repositoryProjects = repositories
            .filter { unclaimedRepositories[$0.url.standardizedFileURL.path] != nil }
            .map { repository in
                Project(
                    workspace: Workspace(
                        name: repository.name,
                        group: repository.group,
                        root: repository.root,
                        url: repository.url,
                        kind: .folder,
                        directories: [repository.url]
                    ),
                    repository: repository
                )
            }

        return (workspaceProjects + repositoryProjects)
            .sorted { ($0.group.lowercased(), $0.name.lowercased()) < ($1.group.lowercased(), $1.name.lowercased()) }
    }
}
