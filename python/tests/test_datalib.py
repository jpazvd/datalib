import os
import sys

import pandas as pd
import pytest

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
import datalib
from datalib import taxonomy as tx


def test_survey_id_uppercases_and_pads():
    assert tx.survey_id("bra", 2019, "mics") == "BRA_2019_MICS"


def test_version_name_master_vs_harmonized():
    assert tx.version_name("BRA", 2023, "SAEB") == "BRA_2023_SAEB_v01_M"
    assert tx.version_name("BRA", 2023, "SAEB", collection="gmd") == \
        "BRA_2023_SAEB_v01_M_v01_A_GMD"


def test_parse_id():
    h = tx.parse_id("BRA_2023_SAEB_v01_M_v01_A_GMD")
    assert h["harmonized"] and h["clct"] == "GMD" and h["kind"] == "harmonized"
    assert tx.parse_id("BRA_2023_SAEB_v01_M")["kind"] == "master"
    assert tx.parse_id("not_an_id") is None


def test_put_get_check_roundtrip(tmp_path):
    root = str(tmp_path)
    df = pd.DataFrame({"id": [1, 2, 3], "x": [10, 20, 30]})
    path = datalib.put(df, country="BRA", year=2023, survey="SAEB", root=root)
    assert os.path.isfile(path)
    got = datalib.get(country="BRA", year=2023, survey="SAEB", root=root)
    assert list(got.columns) == ["id", "x"] and len(got) == 3
    assert datalib.check(root=root) == []


def test_master_is_immutable(tmp_path):
    root = str(tmp_path)
    df = pd.DataFrame({"id": [1]})
    datalib.put(df, country="BRA", year=2023, survey="SAEB", root=root)
    with pytest.raises(FileExistsError):
        datalib.put(df, country="BRA", year=2023, survey="SAEB", root=root)


def test_harmonized_separate_from_master(tmp_path):
    root = str(tmp_path)
    df = pd.DataFrame({"id": [1, 2]})
    m = datalib.put(df, country="BRA", year=2023, survey="SAEB", root=root)
    h = datalib.put(df, country="BRA", year=2023, survey="SAEB",
                    collection="GMD", module="adult", root=root)
    assert "_M_v01_A_GMD" in h and "_M_v01_A_GMD" not in os.path.basename(m)
    assert datalib.check(root=root) == []
