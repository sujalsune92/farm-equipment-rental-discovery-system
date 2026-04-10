import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../services/services.dart';
import '../utils/app_theme.dart';
import '../widgets/widgets.dart';

class FarmerWorkerConnectivityScreen extends StatefulWidget {
  const FarmerWorkerConnectivityScreen({super.key});

  @override
  State<FarmerWorkerConnectivityScreen> createState() => _FarmerWorkerConnectivityScreenState();
}

class _FarmerWorkerConnectivityScreenState extends State<FarmerWorkerConnectivityScreen> {
  final WorkerConnectivityService _service = WorkerConnectivityService();
  final TextEditingController _skillCtrl = TextEditingController();
  final TextEditingController _villageCtrl = TextEditingController();
  String _skillFilter = '';
  String _villageFilter = '';
  bool _nearbyOnly = false;
  double _maxDistanceKm = 25;
  int _workerJobsMode = 0;

  bool get _hasActiveFilters =>
      _skillFilter.trim().isNotEmpty ||
      _villageFilter.trim().isNotEmpty ||
      _nearbyOnly;

  @override
  void dispose() {
    _skillCtrl.dispose();
    _villageCtrl.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _skillCtrl.clear();
      _villageCtrl.clear();
      _skillFilter = '';
      _villageFilter = '';
      _nearbyOnly = false;
      _maxDistanceKm = 25;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final me = auth.currentUser;
    if (me == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isWorker = me.role == AppConstants.roleWorker;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Farmer-Worker Connectivity'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Jobs', icon: Icon(Icons.work_outline)),
              Tab(text: 'Workers', icon: Icon(Icons.groups_outlined)),
              Tab(text: 'Help', icon: Icon(Icons.info_outline)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildJobsTab(context, me, isWorker),
            _buildWorkersTab(context, me, isWorker),
            _buildHelpTab(context),
          ],
        ),
        floatingActionButton: isWorker
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _showCreateJobSheet(context, me),
                icon: const Icon(Icons.add),
                label: const Text('Post Job'),
              ),
      ),
    );
  }

  Widget _buildJobsTab(BuildContext context, UserModel me, bool isWorker) {
    return Column(
      children: [
        _buildFilterPanel(showNearbyControls: isWorker),
        if (isWorker)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Nearby Jobs'),
                  selected: _workerJobsMode == 0,
                  onSelected: (_) => setState(() => _workerJobsMode = 0),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('My Applications'),
                  selected: _workerJobsMode == 1,
                  onSelected: (_) => setState(() => _workerJobsMode = 1),
                ),
              ],
            ),
          ),
        if (isWorker)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              children: [
                SwitchListTile(
                  value: _nearbyOnly,
                  onChanged: (v) => setState(() => _nearbyOnly = v),
                  title: const Text('Nearby only'),
                  subtitle: Text('Max distance: ${_maxDistanceKm.toInt()} km'),
                ),
                if (_nearbyOnly)
                  Slider(
                    value: _maxDistanceKm,
                    min: 5,
                    max: 100,
                    divisions: 19,
                    label: '${_maxDistanceKm.toInt()} km',
                    onChanged: (v) => setState(() => _maxDistanceKm = v),
                  ),
              ],
            ),
          ),
        Expanded(
          child: isWorker
              ? (_workerJobsMode == 0 ? _buildOpenJobsForWorker(me) : _buildAppliedJobsForWorker(me))
              : _buildJobsForFarmer(me),
        ),
      ],
    );
  }

  Widget _buildOpenJobsForWorker(UserModel me) {
    return StreamBuilder<List<WorkerJobPost>>(
      stream: _service.streamOpenJobs(
        village: _villageFilter.trim().isEmpty ? null : _villageFilter.trim(),
        skill: _skillFilter.trim().isEmpty ? null : _skillFilter.trim(),
        workerLat: me.latitude,
        workerLng: me.longitude,
        maxDistanceKm: _nearbyOnly ? _maxDistanceKm : null,
      ),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final jobs = snap.data!;
        if (jobs.isEmpty) {
          return const Center(child: Text('No open jobs match current filters.'));
        }
        return ListView.separated(
          itemCount: jobs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          padding: const EdgeInsets.all(12),
          itemBuilder: (_, i) {
            final job = jobs[i];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(job.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(job.description),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text('Village: ${job.village}')),
                        if (job.distanceKm != null)
                          Chip(label: Text('Distance: ${job.distanceKm!.toStringAsFixed(1)} km')),
                        Chip(label: Text('Date: ${job.workDate}')),
                        Chip(label: Text('Pay: Rs ${job.wageAmount.toStringAsFixed(0)}/${job.wageType}')),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _showApplyDialog(context, me, job),
                          icon: const Icon(Icons.how_to_reg),
                          label: const Text('Apply'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _openJobChat(
                            context,
                            me,
                            jobId: job.id,
                            peerId: job.farmerId,
                            title: job.title,
                          ),
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('Chat'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAppliedJobsForWorker(UserModel me) {
    return StreamBuilder<List<WorkerJobPost>>(
      stream: _service.streamAppliedJobsByWorker(me.id),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final jobs = snap.data!;
        if (jobs.isEmpty) {
          return const Center(child: Text('You have not applied to any job yet.'));
        }
        return ListView.separated(
          itemCount: jobs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          padding: const EdgeInsets.all(12),
          itemBuilder: (_, i) {
            final job = jobs[i];
            return Card(
              child: ListTile(
                title: Text(job.title),
                subtitle: Text('${job.village} | ${job.workDate}\nPay: Rs ${job.wageAmount.toStringAsFixed(0)}/${job.wageType}'),
                isThreeLine: true,
                trailing: OutlinedButton(
                  onPressed: () => _openJobChat(
                    context,
                    me,
                    jobId: job.id,
                    peerId: job.farmerId,
                    title: job.title,
                  ),
                  child: const Text('Chat'),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildJobsForFarmer(UserModel me) {
    return StreamBuilder<List<WorkerJobPost>>(
      stream: _service.streamJobsByFarmer(
        me.id,
        village: _villageFilter.trim().isEmpty ? null : _villageFilter.trim(),
        skill: _skillFilter.trim().isEmpty ? null : _skillFilter.trim(),
      ),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final jobs = snap.data!;
        if (jobs.isEmpty) {
          return const Center(child: Text('No jobs match current filters.'));
        }
        return ListView.separated(
          itemCount: jobs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          padding: const EdgeInsets.all(12),
          itemBuilder: (_, i) {
            final job = jobs[i];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(job.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                        StatusBadge(job.status == 'open' ? 'Approved' : 'Declined'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(job.description),
                    const SizedBox(height: 8),
                    Text('Village: ${job.village}  |  Date: ${job.workDate}'),
                    Text('Wage: Rs ${job.wageAmount.toStringAsFixed(0)}/${job.wageType}'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _showApplicantsSheet(context, me, job),
                          icon: const Icon(Icons.people_outline),
                          label: const Text('Applications'),
                        ),
                        if (job.status == 'open')
                          OutlinedButton.icon(
                            onPressed: () => _service.updateJobStatus(job.id, 'closed'),
                            icon: const Icon(Icons.lock_outline),
                            label: const Text('Close Job'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWorkersTab(BuildContext context, UserModel me, bool isWorker) {
    if (isWorker) {
      return _WorkerRegistrationForm(service: _service, user: me);
    }

    return Column(
      children: [
        _buildFilterPanel(showNearbyControls: false),
        Expanded(
          child: StreamBuilder<List<WorkerProfile>>(
            stream: _service.streamWorkers(
              village: _villageFilter.trim().isEmpty ? null : _villageFilter.trim(),
              skill: _skillFilter.trim().isEmpty ? null : _skillFilter.trim(),
            ),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final workers = snap.data!;
              if (workers.isEmpty) {
                return const Center(child: Text('No available workers for current filters.'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: workers.length,
                itemBuilder: (_, i) {
                  final w = workers[i];
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                      title: Text(w.fullName),
                      subtitle: Text('${w.village}\nSkills: ${w.skills.join(', ')}'),
                      trailing: Text('Rs ${w.hourlyRate.toStringAsFixed(0)}/hr'),
                      isThreeLine: true,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterPanel({required bool showNearbyControls}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.tune, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Filters',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (_hasActiveFilters)
                    TextButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Clear'),
                    ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _skillCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Skill',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (v) => setState(() => _skillFilter = v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _villageCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Village',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                      onChanged: (v) => setState(() => _villageFilter = v),
                    ),
                  ),
                ],
              ),
              if (_hasActiveFilters) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (_skillFilter.trim().isNotEmpty)
                      Chip(label: Text('Skill: ${_skillFilter.trim()}')),
                    if (_villageFilter.trim().isNotEmpty)
                      Chip(label: Text('Village: ${_villageFilter.trim()}')),
                    if (showNearbyControls && _nearbyOnly)
                      Chip(label: Text('Nearby: ${_maxDistanceKm.toInt()} km')),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHelpTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Card(
          child: ListTile(
            leading: Icon(Icons.person_add_alt_1),
            title: Text('Worker Registration'),
            subtitle: Text('Workers can register skills, location, wage, and availability.'),
          ),
        ),
        Card(
          child: ListTile(
            leading: Icon(Icons.post_add),
            title: Text('Job Posting'),
            subtitle: Text('Farmers can post field jobs with date, village, skills, and wage.'),
          ),
        ),
        Card(
          child: ListTile(
            leading: Icon(Icons.auto_awesome),
            title: Text('Matching System'),
            subtitle: Text('Filter by village and skill to shortlist suitable workers/jobs.'),
          ),
        ),
        Card(
          child: ListTile(
            leading: Icon(Icons.chat_outlined),
            title: Text('Communication'),
            subtitle: Text('Per-job chat allows direct coordination between farmer and worker.'),
          ),
        ),
      ],
    );
  }

  Future<void> _showCreateJobSheet(BuildContext context, UserModel me) async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final villageCtrl = TextEditingController(text: me.address ?? '');
    final dateCtrl = TextEditingController();
    final wageCtrl = TextEditingController();
    final skillsCtrl = TextEditingController();
    String wageType = 'day';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (ctx, setModalState) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Post Worker Job', style: Theme.of(ctx).textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Job title')),
                    const SizedBox(height: 8),
                    TextField(controller: descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
                    const SizedBox(height: 8),
                    TextField(controller: villageCtrl, decoration: const InputDecoration(labelText: 'Village')),
                    const SizedBox(height: 8),
                    TextField(controller: dateCtrl, decoration: const InputDecoration(labelText: 'Work date (YYYY-MM-DD)')),
                    const SizedBox(height: 8),
                    TextField(controller: wageCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Wage amount')),
                    const SizedBox(height: 8),
                    TextField(controller: skillsCtrl, decoration: const InputDecoration(labelText: 'Required skills (comma separated)')),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: wageType,
                      items: const [
                        DropdownMenuItem(value: 'hour', child: Text('Per hour')),
                        DropdownMenuItem(value: 'day', child: Text('Per day')),
                      ],
                      onChanged: (v) => setModalState(() => wageType = v ?? 'day'),
                      decoration: const InputDecoration(labelText: 'Wage type'),
                    ),
                    const SizedBox(height: 14),
                    PrimaryButton(
                      text: 'Create Job',
                      icon: Icons.check,
                      onPressed: () async {
                        final amount = double.tryParse(wageCtrl.text.trim()) ?? 0;
                        final skills = skillsCtrl.text
                            .split(',')
                            .map((e) => e.trim())
                            .where((e) => e.isNotEmpty)
                            .toList();
                        if (titleCtrl.text.trim().isEmpty || villageCtrl.text.trim().isEmpty || amount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please fill required job fields.')),
                          );
                          return;
                        }

                        await _service.createJob(
                          WorkerJobPost(
                            id: '',
                            farmerId: me.id,
                            farmerName: me.name,
                            title: titleCtrl.text.trim(),
                            description: descCtrl.text.trim(),
                            village: villageCtrl.text.trim(),
                            latitude: me.latitude,
                            longitude: me.longitude,
                            workDate: dateCtrl.text.trim(),
                            wageType: wageType,
                            wageAmount: amount,
                            requiredSkills: skills,
                            status: 'open',
                            createdAt: DateTime.now(),
                          ),
                        );
                        if (context.mounted) Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showApplyDialog(BuildContext context, UserModel me, WorkerJobPost job) async {
    final noteCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apply for Job'),
        content: TextField(
          controller: noteCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Message to farmer',
            hintText: 'Share your experience and availability',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await _service.applyForJob(
                jobId: job.id,
                workerId: me.id,
                workerName: me.name,
                note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
              );
              if (context.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Application sent successfully.')),
                );
              }
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Future<void> _showApplicantsSheet(BuildContext context, UserModel me, WorkerJobPost job) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.65,
        child: StreamBuilder<List<WorkerApplication>>(
          stream: _service.streamApplicationsForJob(job.id),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final apps = snap.data!;
            if (apps.isEmpty) {
              return const Center(child: Text('No applications yet.'));
            }
            return ListView.builder(
              itemCount: apps.length,
              itemBuilder: (_, i) {
                final app = apps[i];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                  title: Text(app.workerName),
                  subtitle: Text('Status: ${app.status}${app.note != null ? '\n${app.note}' : ''}'),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      IconButton(
                        tooltip: 'Accept',
                        onPressed: () => _service.updateApplicationStatus(app.id, 'accepted'),
                        icon: const Icon(Icons.check_circle_outline, color: AppColors.success),
                      ),
                      IconButton(
                        tooltip: 'Chat',
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openJobChat(
                            context,
                            me,
                            jobId: job.id,
                            peerId: app.workerId,
                            title: '${job.title} - ${app.workerName}',
                          );
                        },
                        icon: const Icon(Icons.chat_bubble_outline),
                      ),
                    ],
                  ),
                  isThreeLine: app.note != null,
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _openJobChat(
    BuildContext context,
    UserModel me, {
    required String jobId,
    required String peerId,
    required String title,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _JobChatScreen(
          service: _service,
          me: me,
          jobId: jobId,
          peerId: peerId,
          title: title,
        ),
      ),
    );
  }
}

class _WorkerRegistrationForm extends StatefulWidget {
  final WorkerConnectivityService service;
  final UserModel user;

  const _WorkerRegistrationForm({required this.service, required this.user});

  @override
  State<_WorkerRegistrationForm> createState() => _WorkerRegistrationFormState();
}

class _WorkerRegistrationFormState extends State<_WorkerRegistrationForm> {
  final _villageCtrl = TextEditingController();
  final _skillsCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();
  final _workTypeCtrl = TextEditingController();
  final _radiusCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  bool _verified = false;
  bool _available = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await widget.service.getMyWorkerProfile(widget.user.id);
    if (profile == null) return;
    if (!mounted) return;
    setState(() {
      _villageCtrl.text = profile.village;
      _skillsCtrl.text = profile.skills.join(', ');
      _rateCtrl.text = profile.hourlyRate.toStringAsFixed(0);
      _experienceCtrl.text = profile.experienceYears.toString();
      _workTypeCtrl.text = profile.primaryWorkType;
      _radiusCtrl.text = profile.preferredRadiusKm.toStringAsFixed(0);
      _verified = profile.identityVerified;
      _bioCtrl.text = profile.bio;
      _available = profile.isAvailable;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Worker Registration', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Update your profile so farmers can find and contact you.'),
        const SizedBox(height: 14),
        TextField(controller: _villageCtrl, decoration: const InputDecoration(labelText: 'Village')),
        const SizedBox(height: 10),
        TextField(controller: _skillsCtrl, decoration: const InputDecoration(labelText: 'Skills (comma separated)')),
        const SizedBox(height: 10),
        TextField(
          controller: _rateCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Hourly Rate (Rs)'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _experienceCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Experience (years)'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _workTypeCtrl,
          decoration: const InputDecoration(labelText: 'Primary Work Type (e.g. Harvesting)'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _radiusCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Preferred Work Radius (km)'),
        ),
        const SizedBox(height: 10),
        SwitchListTile(
          value: _verified,
          onChanged: (v) => setState(() => _verified = v),
          title: const Text('Identity verified'),
        ),
        const SizedBox(height: 10),
        TextField(controller: _bioCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Short Bio')),
        const SizedBox(height: 10),
        SwitchListTile(
          value: _available,
          onChanged: (v) => setState(() => _available = v),
          title: const Text('Available for work'),
          activeThumbColor: AppColors.primary,
        ),
        const SizedBox(height: 10),
        PrimaryButton(
          text: 'Save Profile',
          icon: Icons.save,
          isLoading: _saving,
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            setState(() => _saving = true);
            final rate = double.tryParse(_rateCtrl.text.trim()) ?? 0;
            final exp = int.tryParse(_experienceCtrl.text.trim()) ?? 0;
            final radiusKm = double.tryParse(_radiusCtrl.text.trim()) ?? 25;
            final skills = _skillsCtrl.text
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
            await widget.service.upsertWorkerProfile(
              WorkerProfile(
                userId: widget.user.id,
                fullName: widget.user.name,
                phone: widget.user.phone,
                skills: skills,
                village: _villageCtrl.text.trim(),
                latitude: widget.user.latitude,
                longitude: widget.user.longitude,
                hourlyRate: rate,
                experienceYears: exp,
                primaryWorkType: _workTypeCtrl.text.trim().isEmpty ? 'General Farm Work' : _workTypeCtrl.text.trim(),
                preferredRadiusKm: radiusKm,
                identityVerified: _verified,
                isAvailable: _available,
                bio: _bioCtrl.text.trim(),
                updatedAt: DateTime.now(),
              ),
            );
            if (!context.mounted) return;
            setState(() => _saving = false);
            messenger.showSnackBar(
              const SnackBar(content: Text('Worker profile saved.')),
            );
          },
        ),
      ],
    );
  }
}

class _JobChatScreen extends StatefulWidget {
  final WorkerConnectivityService service;
  final UserModel me;
  final String jobId;
  final String peerId;
  final String title;

  const _JobChatScreen({
    required this.service,
    required this.me,
    required this.jobId,
    required this.peerId,
    required this.title,
  });

  @override
  State<_JobChatScreen> createState() => _JobChatScreenState();
}

class _JobChatScreenState extends State<_JobChatScreen> {
  final TextEditingController _msgCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<WorkerMessage>>(
              stream: widget.service.streamMessages(widget.jobId),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final messages = snap.data!;
                if (messages.isEmpty) {
                  return const Center(child: Text('No messages yet. Start the conversation.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final msg = messages[i];
                    final mine = msg.senderId == widget.me.id;
                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(10),
                        constraints: const BoxConstraints(maxWidth: 280),
                        decoration: BoxDecoration(
                          color: mine ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Text(
                          msg.body,
                          style: TextStyle(color: mine ? Colors.white : AppColors.textPrimary),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Type message...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () async {
                      final body = _msgCtrl.text.trim();
                      if (body.isEmpty) return;
                      _msgCtrl.clear();
                      await widget.service.sendMessage(
                        jobId: widget.jobId,
                        senderId: widget.me.id,
                        receiverId: widget.peerId,
                        body: body,
                      );
                    },
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
