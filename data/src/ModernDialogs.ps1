# ============================================================
# ModernDialogs.ps1 - Windows modern Common Item Dialog wrappers
# Uses the native Windows IFileOpenDialog (Windows 10/11 style).
# ============================================================

if (-not ('GIS.NativeFileDialog' -as [type])) {
    $nativeDialogSource = @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

namespace GIS {
    [Flags]
    internal enum FileOpenOptions : uint {
        OverwritePrompt = 0x00000002,
        StrictFileTypes = 0x00000004,
        NoChangeDirectory = 0x00000008,
        PickFolders = 0x00000020,
        ForceFileSystem = 0x00000040,
        AllowMultiSelect = 0x00000200,
        PathMustExist = 0x00000800,
        FileMustExist = 0x00001000,
        DontAddToRecent = 0x02000000
    }

    internal enum ShellItemDisplayName : uint {
        FileSystemPath = 0x80058000
    }

    [ComImport, Guid("42F85136-DB7E-439C-85F1-E4075D135FC8"),
     InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IFileDialog {
        [PreserveSig] int Show(IntPtr owner);
        [PreserveSig] int SetFileTypes(uint count, IntPtr filters);
        [PreserveSig] int SetFileTypeIndex(uint index);
        [PreserveSig] int GetFileTypeIndex(out uint index);
        [PreserveSig] int Advise(IntPtr events, out uint cookie);
        [PreserveSig] int Unadvise(uint cookie);
        [PreserveSig] int SetOptions(FileOpenOptions options);
        [PreserveSig] int GetOptions(out FileOpenOptions options);
        [PreserveSig] int SetDefaultFolder(IShellItem folder);
        [PreserveSig] int SetFolder(IShellItem folder);
        [PreserveSig] int GetFolder(out IShellItem folder);
        [PreserveSig] int GetCurrentSelection(out IShellItem item);
        [PreserveSig] int SetFileName([MarshalAs(UnmanagedType.LPWStr)] string name);
        [PreserveSig] int GetFileName(out IntPtr name);
        [PreserveSig] int SetTitle([MarshalAs(UnmanagedType.LPWStr)] string title);
        [PreserveSig] int SetOkButtonLabel([MarshalAs(UnmanagedType.LPWStr)] string text);
        [PreserveSig] int SetFileNameLabel([MarshalAs(UnmanagedType.LPWStr)] string label);
        [PreserveSig] int GetResult(out IShellItem item);
        [PreserveSig] int AddPlace(IShellItem item, int alignment);
        [PreserveSig] int SetDefaultExtension([MarshalAs(UnmanagedType.LPWStr)] string extension);
        [PreserveSig] int Close(int result);
        [PreserveSig] int SetClientGuid(ref Guid guid);
        [PreserveSig] int ClearClientData();
        [PreserveSig] int SetFilter(IntPtr filter);
        [PreserveSig] int SetPreviewMode([MarshalAs(UnmanagedType.Bool)] bool preview);
        [PreserveSig] int SetSearchCriteria(IShellItemArray searchCriteria);
    }

    [ComImport, Guid("D57C7288-D4AD-4768-BE02-9D969532D960"),
     InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IFileOpenDialog {
        [PreserveSig] int Show(IntPtr owner);
        [PreserveSig] int SetFileTypes(uint count, IntPtr filters);
        [PreserveSig] int SetFileTypeIndex(uint index);
        [PreserveSig] int GetFileTypeIndex(out uint index);
        [PreserveSig] int Advise(IntPtr events, out uint cookie);
        [PreserveSig] int Unadvise(uint cookie);
        [PreserveSig] int SetOptions(FileOpenOptions options);
        [PreserveSig] int GetOptions(out FileOpenOptions options);
        [PreserveSig] int SetDefaultFolder(IShellItem folder);
        [PreserveSig] int SetFolder(IShellItem folder);
        [PreserveSig] int GetFolder(out IShellItem folder);
        [PreserveSig] int GetCurrentSelection(out IShellItem item);
        [PreserveSig] int SetFileName([MarshalAs(UnmanagedType.LPWStr)] string name);
        [PreserveSig] int GetFileName(out IntPtr name);
        [PreserveSig] int SetTitle([MarshalAs(UnmanagedType.LPWStr)] string title);
        [PreserveSig] int SetOkButtonLabel([MarshalAs(UnmanagedType.LPWStr)] string text);
        [PreserveSig] int SetFileNameLabel([MarshalAs(UnmanagedType.LPWStr)] string label);
        [PreserveSig] int GetResult(out IShellItem item);
        [PreserveSig] int AddPlace(IShellItem item, int alignment);
        [PreserveSig] int SetDefaultExtension([MarshalAs(UnmanagedType.LPWStr)] string extension);
        [PreserveSig] int Close(int result);
        [PreserveSig] int SetClientGuid(ref Guid guid);
        [PreserveSig] int ClearClientData();
        [PreserveSig] int SetFilter(IntPtr filter);
        [PreserveSig] int SetPreviewMode([MarshalAs(UnmanagedType.Bool)] bool preview);
        [PreserveSig] int SetSearchCriteria(IShellItemArray searchCriteria);
        [PreserveSig] int GetResults(out IShellItemArray results);
        [PreserveSig] int GetSelectedItems(out IShellItemArray items);
    }

    [ComImport, Guid("43826D1E-E718-42EE-BC55-A1E261C37BFE"),
     InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IShellItem {
        [PreserveSig] int BindToHandler(IntPtr binding, ref Guid handler, ref Guid iid, out IntPtr result);
        [PreserveSig] int GetParent(out IShellItem parent);
        [PreserveSig] int GetDisplayName(ShellItemDisplayName name, out IntPtr value);
        [PreserveSig] int GetAttributes(uint mask, out uint attributes);
        [PreserveSig] int Compare(IShellItem other, uint hint, out int order);
    }

    [ComImport, Guid("B63EA76D-1F85-456F-A19C-48159EFA858B"),
     InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IShellItemArray {
        [PreserveSig] int BindToHandler(IntPtr binding, ref Guid handler, ref Guid iid, out IntPtr result);
        [PreserveSig] int GetPropertyStore(uint flags, ref Guid iid, out IntPtr store);
        [PreserveSig] int GetPropertyDescriptionList(IntPtr key, ref Guid iid, out IntPtr descriptions);
        [PreserveSig] int GetAttributes(uint flags, uint mask, out uint attributes);
        [PreserveSig] int GetCount(out uint count);
        [PreserveSig] int GetItemAt(uint index, out IShellItem item);
        [PreserveSig] int EnumItems(out IntPtr enumerator);
    }

    public static class NativeFileDialog {
        private static readonly Guid FileOpenDialogClass = new Guid("DC1C5A9C-E88A-4DDE-A5A1-60F82A20AEF7");
        private const int ErrorCancelled = unchecked((int)0x800704C7);

        [DllImport("shell32.dll", CharSet = CharSet.Unicode, PreserveSig = true)]
        private static extern int SHCreateItemFromParsingName(
            [MarshalAs(UnmanagedType.LPWStr)] string path,
            IntPtr binding,
            ref Guid iid,
            out IShellItem item);

        private static IFileOpenDialog CreateDialog() {
            Type type = Type.GetTypeFromCLSID(FileOpenDialogClass, true);
            return (IFileOpenDialog)Activator.CreateInstance(type);
        }

        private static void SetInitialFolder(IFileOpenDialog dialog, string path) {
            if (String.IsNullOrWhiteSpace(path) || !System.IO.Directory.Exists(path)) return;
            IShellItem item = null;
            try {
                Guid iid = typeof(IShellItem).GUID;
                int hr = SHCreateItemFromParsingName(path, IntPtr.Zero, ref iid, out item);
                if (hr >= 0 && item != null) dialog.SetFolder(item);
            } finally {
                if (item != null && Marshal.IsComObject(item)) Marshal.ReleaseComObject(item);
            }
        }

        private static string GetPath(IShellItem item) {
            if (item == null) return null;
            IntPtr pointer = IntPtr.Zero;
            try {
                int hr = item.GetDisplayName(ShellItemDisplayName.FileSystemPath, out pointer);
                if (hr < 0) Marshal.ThrowExceptionForHR(hr);
                return Marshal.PtrToStringUni(pointer);
            } finally {
                if (pointer != IntPtr.Zero) Marshal.FreeCoTaskMem(pointer);
            }
        }

        public static string PickFolder(IntPtr owner, string title, string initialFolder) {
            IFileOpenDialog dialog = null;
            try {
                dialog = CreateDialog();
                FileOpenOptions options = FileOpenOptions.PickFolders |
                    FileOpenOptions.ForceFileSystem |
                    FileOpenOptions.PathMustExist |
                    FileOpenOptions.NoChangeDirectory |
                    FileOpenOptions.DontAddToRecent;
                dialog.SetOptions(options);
                dialog.SetTitle(String.IsNullOrWhiteSpace(title) ? "Choose a folder" : title);
                dialog.SetOkButtonLabel("Select Folder");
                SetInitialFolder(dialog, initialFolder);
                int hr = dialog.Show(owner);
                if (hr == ErrorCancelled) return null;
                if (hr < 0) Marshal.ThrowExceptionForHR(hr);
                IShellItem result = null;
                try {
                    hr = dialog.GetResult(out result);
                    if (hr < 0) Marshal.ThrowExceptionForHR(hr);
                    return GetPath(result);
                } finally {
                    if (result != null && Marshal.IsComObject(result)) Marshal.ReleaseComObject(result);
                }
            } finally {
                if (dialog != null && Marshal.IsComObject(dialog)) Marshal.ReleaseComObject(dialog);
            }
        }

        public static string[] PickFiles(IntPtr owner, string title, string initialFolder) {
            IFileOpenDialog dialog = null;
            List<string> paths = new List<string>();
            try {
                dialog = CreateDialog();
                FileOpenOptions options = FileOpenOptions.ForceFileSystem |
                    FileOpenOptions.PathMustExist |
                    FileOpenOptions.FileMustExist |
                    FileOpenOptions.AllowMultiSelect |
                    FileOpenOptions.NoChangeDirectory |
                    FileOpenOptions.DontAddToRecent;
                dialog.SetOptions(options);
                dialog.SetTitle(String.IsNullOrWhiteSpace(title) ? "Select files" : title);
                SetInitialFolder(dialog, initialFolder);
                int hr = dialog.Show(owner);
                if (hr == ErrorCancelled) return new string[0];
                if (hr < 0) Marshal.ThrowExceptionForHR(hr);
                IShellItemArray results = null;
                try {
                    hr = dialog.GetResults(out results);
                    if (hr < 0) Marshal.ThrowExceptionForHR(hr);
                    uint count = 0;
                    hr = results.GetCount(out count);
                    if (hr < 0) Marshal.ThrowExceptionForHR(hr);
                    for (uint i = 0; i < count; i++) {
                        IShellItem item = null;
                        try {
                            hr = results.GetItemAt(i, out item);
                            if (hr < 0) continue;
                            string path = GetPath(item);
                            if (!String.IsNullOrWhiteSpace(path)) paths.Add(path);
                        } finally {
                            if (item != null && Marshal.IsComObject(item)) Marshal.ReleaseComObject(item);
                        }
                    }
                } finally {
                    if (results != null && Marshal.IsComObject(results)) Marshal.ReleaseComObject(results);
                }
                return paths.ToArray();
            } finally {
                if (dialog != null && Marshal.IsComObject(dialog)) Marshal.ReleaseComObject(dialog);
            }
        }
    }
}
'@
    Add-Type -TypeDefinition $nativeDialogSource -Language CSharp -ErrorAction Stop
}

function Test-ModernFileDialogAvailable {
    return [bool]('GIS.NativeFileDialog' -as [type])
}
