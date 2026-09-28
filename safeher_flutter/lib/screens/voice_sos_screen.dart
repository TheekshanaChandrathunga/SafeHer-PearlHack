import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:share_plus/share_plus.dart';

import '../models/alert_model.dart';
import '../services/alert_service.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';

class VoiceSosScreen extends StatefulWidget {
  const VoiceSosScreen({super.key});

  @override
  State<VoiceSosScreen> createState() => _VoiceSosScreenState();
}

class _VoiceSosScreenState extends State<VoiceSosScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  bool _recording = false;
  bool _sending = false;
  String? _recordingPath;
  String? _message;

  @override
  void initState() {
    super.initState();
    _startRecording();
  }

  Future<void> _startRecording() async {
    try {
      if (!await _recorder.hasPermission()) {
        if (mounted) {
          setState(() => _message = 'Microphone permission is required.');
        }
        return;
      }
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: 'safeher_voice_sos.m4a',
      );
      if (mounted) setState(() => _recording = true);
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Unable to access the microphone.');
      }
    }
  }

  Future<void> _stopRecording() async {
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() {
      _recording = false;
      _recordingPath = path;
      _message =
          path == null ? 'No recording was captured.' : 'Voice message ready.';
    });
  }

  Future<void> _sendVoiceMessage() async {
    if (_recording) await _stopRecording();
    final path = _recordingPath;
    if (path == null) return;

    setState(() {
      _sending = true;
      _message = 'Preparing your voice SOS...';
    });

    try {
      final firebase = FirebaseService.instance;
      final contacts = await firebase.watchContacts().first;
      final settings = await firebase.watchSettings().first;
      final alertId =
          await AlertService(firebase, LocationService()).triggerAlert(
        source: AlertSource.voice,
        contacts: contacts,
        autoCall: false,
        notifyAuthorities: settings['notifyAuthorities'] ?? true,
      );

      await Share.shareXFiles(
        [XFile(path)],
        text: 'SafeHer voice SOS. Alert ID: $alertId',
      );
      if (mounted) {
        setState(() => _message = 'Voice SOS sent to the share target.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'The voice message could not be sent.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Voice SOS')),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SizedBox(
                height: constraints.maxHeight - 48,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 36),
                    CircleAvatar(
                      radius: 64,
                      backgroundColor:
                          _recording ? AppColors.red : AppColors.purple,
                      child: Icon(
                        _recording ? Icons.mic : Icons.mic_none,
                        color: Colors.white,
                        size: 54,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _recording
                          ? 'Recording your voice SOS'
                          : 'Voice SOS ready',
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _message ??
                          'Speak clearly, then send the recording to your emergency contact.',
                      style: const TextStyle(color: AppColors.muted),
                      textAlign: TextAlign.center,
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: _recording
                          ? FilledButton.icon(
                              onPressed: _stopRecording,
                              icon: const Icon(Icons.stop),
                              label: const Text('Stop recording'),
                            )
                          : FilledButton.icon(
                              onPressed: _sending ? null : _sendVoiceMessage,
                              icon: const Icon(Icons.send),
                              label: Text(_sending
                                  ? 'Sending...'
                                  : 'Send voice message'),
                            ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _sending ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
