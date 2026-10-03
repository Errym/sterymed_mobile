import 'package:flutter/material.dart';

import '../../data/models/prosthetic_case_attachment_data.dart';

/// One attachment of a case. Tapping it opens it (image viewer / PDF reader);
/// the delete cross only exists for people who may change the case.
class ProstheticAttachmentChip extends StatelessWidget {
  final ProstheticCaseAttachmentData attachment;
  final VoidCallback? onOpen;
  final VoidCallback? onDelete;
  const ProstheticAttachmentChip({
    super.key,
    required this.attachment,
    this.onOpen,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InputChip(
      avatar: Icon(
        attachment.isImage
            ? Icons.image_outlined
            : Icons.picture_as_pdf_outlined,
        size: 18,
      ),
      label: Text(attachment.fileName ?? 'Fichier',
          overflow: TextOverflow.ellipsis),
      onPressed: onOpen,
      onDeleted: onDelete,
    );
  }
}
