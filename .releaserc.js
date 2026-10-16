// semantic-release — https://semantic-release.gitbook.io
// Runs in CI on every push to main (.github/workflows/release.yml) and
// publishes a GitHub Release + git tag. No CHANGELOG.md, no commit back.
// The same setup as homelab-proxmox-core's (its .releaserc.js has the
// history behind each choice).
//
// preset: `conventionalcommits`, matching commitlint. NOT `angular`: its
// parser doesn't understand the `type!:` header, so `feat!: ...` would
// produce no release.
//
// conventional-changelog-conventionalcommits is held at ^9 in package.json:
// 10.x needs conventional-changelog-writer@9, but
// @semantic-release/release-notes-generator 14.x still depends on writer
// ^8, and generating the notes fails. Move to ^10 only together with a
// release-notes-generator on writer@9.
//
// branches: main only, as the release workflow's trigger.
//
// tagFormat: unprefixed (`1.2.0`), like homelab-proxmox-core's and
// terraform-elasticstack-workspace's tags. The first release is 1.0.0.
module.exports = {
  branches: ['main'],
  tagFormat: '${version}',
  plugins: [
    ['@semantic-release/commit-analyzer', { preset: 'conventionalcommits' }],
    [
      '@semantic-release/release-notes-generator',
      {
        preset: 'conventionalcommits',
        writerOpts: {
          commitsSort: ['scope', 'subject'],
        },
      },
    ],
    '@semantic-release/github',
  ],
};
