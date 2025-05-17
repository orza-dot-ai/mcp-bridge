import pydicom
import datetime
import os
import json

# file_path = '/Users/roman/v3.cash/orza/platform/priv/static/uploads/live_view_upload-1746728239-515012552728-6-sample.dcm'
if isinstance(file_path, bytes):
    file_path = file_path.decode('utf-8')

try:
    ds = pydicom.dcmread(file_path, force=True) # Use pydicom.dcmread, force=True can help with some non-compliant files
except Exception as e:
    print(f"Error reading DICOM file with pydicom: {e} at path: {file_path}")
    ds = None # Ensure ds is defined even if reading fails

def convert_headers(obj):
    if hasattr(obj, "to_dict") and not isinstance(obj, (pydicom.dataset.FileDataset, pydicom.dataset.Dataset, pydicom.sequence.Sequence, pydicom.multival.MultiValue)):
        # This condition might be too broad now, pydicom objects don't typically have to_dict() like dicom_parser's header
        # We'll primarily rely on isinstance checks for pydicom types
        return convert_headers(obj.to_dict())
    elif isinstance(obj, list) and not isinstance(obj, pydicom.multival.MultiValue): # Exclude MultiValue from general list handling
        return [convert_headers(item) for item in obj]
    elif isinstance(obj, tuple):
        return [convert_headers(item) for item in obj]
    elif isinstance(obj, dict):
        return {k: convert_headers(v) for k, v in obj.items()}
    elif isinstance(obj, pydicom.multival.MultiValue):
        # Convert MultiValue to a list of native Python types
        return [convert_headers(item) for item in obj] # obj itself is iterable
    elif isinstance(obj, pydicom.sequence.Sequence):
        # Convert Sequence to a list of dictionaries (Dataset objects)
        return [convert_headers(item) for item in obj] # obj itself is iterable
    elif isinstance(obj, (pydicom.dataset.FileDataset, pydicom.dataset.Dataset)):
        # Convert pydicom Dataset to a dictionary
        temp_dict = {}
        for data_element in obj:
            key = data_element.keyword if data_element.keyword else str(data_element.tag)
            # Skip pixel data from metadata, and other large binary data if necessary
            if data_element.tag == (0x7FE0, 0x0010): # Pixel Data tag
                continue
            # One might also want to skip other large binary blobs, e.g., 'OverlayData', 'EncryptedAttributesSequence', etc.
            # For now, just skipping PixelData as per common practice for metadata.
            temp_dict[key] = convert_headers(data_element.value)
        return temp_dict
    elif isinstance(obj, datetime.date) and not isinstance(obj, datetime.datetime):
        return {"year": obj.year, "month": obj.month, "day": obj.day}
    elif isinstance(obj, datetime.time):
        return {
            "hour": obj.hour,
            "minute": obj.minute,
            "second": obj.second,
            "microsecond": obj.microsecond
        }
    # Handle pydicom specific valuerep types
    elif isinstance(obj, pydicom.valuerep.PersonName):
        # Deconstruct PersonName into a dictionary
        # components() returns a tuple of 5 strings: family, given, middle, prefix, suffix
        # or a list of such tuples if it's a multi-valued PersonName (handled by MultiValue itself)
        # For a single PersonName object, we can access properties directly or iterate components
        # Using direct properties is more explicit and robust if available and consistent.
        # pydicom's PersonName string representation is also quite good via str(obj)
        # Let's try to build a dict from known components.
        # Note: A PersonName object can represent multiple names (groups of components).
        # The object itself is an iterable of component groups if it's from a multi-valued PN tag.
        # However, convert_headers(data_element.value) for a multi-value PN tag should receive a MultiValue object first.
        # So, here 'obj' should be a single PersonName representative string or a PersonName object for a single name.
        # If obj is a pydicom.valuerep.PersonName object:
        # It has properties like: family_name, given_name, middle_name, name_prefix, name_suffix
        # For simplicity and common use, we'll convert it to its string representation here.
        # A more detailed conversion could be:
        # return {
        #     'family_name': str(obj.family_name) if obj.family_name else None,
        #     'given_name': str(obj.given_name) if obj.given_name else None,
        #     'middle_name': str(obj.middle_name) if obj.middle_name else None,
        #     'name_prefix': str(obj.name_prefix) if obj.name_prefix else None,
        #     'name_suffix': str(obj.name_suffix) if obj.name_suffix else None,
        #     'formatted': str(obj) # Full formatted name string
        # }
        # Based on user's successful test: headers.get('ReferringPhysicianName').components() -> ('HUGHES^KATHLEEN',)
        # And then headers.get('ReferringPhysicianName') -> {'family_name': 'HUGHES', ...}
        # This implies pydicom already did some conversion or user modified it before the last run.
        # Let's assume 'obj' here *is* the PersonName object from pydicom.value
        if hasattr(obj, 'family_name'): # A good check if it's a parsed PersonName object
             # Prefer structured dict for PersonName
            pn_dict = {
                comp_name: str(getattr(obj, comp_name)) if getattr(obj, comp_name) is not None else ''
                for comp_name in ['family_name', 'given_name', 'middle_name', 'name_prefix', 'name_suffix']
            }
            # Add ideographic and phonetic if they exist (DICOM standard components)
            if hasattr(obj, 'ideographic_representation'):
                pn_dict['ideographic_representation'] = str(obj.ideographic_representation)
            if hasattr(obj, 'phonetic_representation'):
                pn_dict['phonetic_representation'] = str(obj.phonetic_representation)
            return pn_dict
        else: # Fallback if it's not a fully parsed PersonName object but still of that type
            return str(obj)

    # General handling for other pydicom valuerep types (like IS, DS, etc.) that behave like strings or numbers
    # or custom objects that might have a dictionary representation
    elif not isinstance(obj, (str, int, float, bool, type(None))):
        # Try common dictionary conversion methods
        for method_name in ['_as_dict', 'as_dict', 'to_dict', '_to_dict']:
            if hasattr(obj, method_name) and callable(getattr(obj, method_name)):
                try:
                    return convert_headers(getattr(obj, method_name)()) # Recurse on the dict
                except Exception as e:
                    print(f"Error calling {method_name} on {type(obj)}: {e}")
                    # Continue to try other methods or string conversion
                    pass
        # Try to convert to string as a fallback for other types
        # Fallback for pydicom DataElement or unknown objects not caught by earlier specific isinstance checks
        if hasattr(obj, 'value'):
            val = obj.value
            if isinstance(val, (bytes, bytearray)):
                try:
                    return val.decode('utf-8', errors='replace').strip()
                except Exception: # Broad exception for any decoding error
                    return repr(val) # If not decodable text, return its representation
            return convert_headers(val) # Recurse on the value

        if isinstance(obj, (bytes, bytearray)):
            try:
                return obj.decode('utf-8', errors='replace').strip()
            except Exception: # Broad exception for any decoding error
                return repr(obj) # If not decodable text, return its representation

        # If all else fails, convert to string or representation
        try:
            return str(obj)
        except Exception:
            return repr(obj)
    else:
        # Basic types (str, int, float, bool, None) are returned as is
        return obj

headers = {}
if ds is None:
    print("Error: ds is None. The DICOM file may be invalid or unreadable.")
else:
    headers = convert_headers(ds)

headers